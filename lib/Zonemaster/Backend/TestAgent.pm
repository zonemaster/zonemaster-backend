package Zonemaster::Backend::TestAgent;
our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;
use Scalar::Util qw( blessed );
use File::Slurp;
use Log::Any qw( $log );

use Zonemaster::LDNS;

use Zonemaster::Engine;
use Zonemaster::Engine::Translator;
use Zonemaster::Backend::Config;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Logger::Entry;

sub new {
    my ( $class, $params ) = @_;
    my $self = {};

    if ( !$params || !$params->{config} ) {
        die "missing 'config' parameter";
    }

    my $config = $params->{config};

    my $dbtype;
    if ( $params->{dbtype} ) {
        $dbtype = $config->check_db( $params->{dbtype} );
    }
    else {
        $dbtype = $config->DB_engine;
    }

    my $dbclass = Zonemaster::Backend::DB->get_db_class( $dbtype );
    $self->{_db} = $dbclass->from_config( $config );

    my %all_profiles = ( $config->PUBLIC_PROFILES, $config->PRIVATE_PROFILES );
    foreach my $name ( keys %all_profiles ) {
        my $path = $all_profiles{$name};

        my $full_profile = Zonemaster::Engine::Profile->default;
        if ( defined $path ) {
            my $json = eval { read_file( $path, err_mode => 'croak' ) }    #
              // die "Error loading profile '$name': $@";
            my $named_profile = eval { Zonemaster::Engine::Profile->from_json( $json ) }    #
              // die "Error loading profile '$name' at '$path': $@";
            $full_profile->merge( $named_profile );
        }
        $self->{_profiles}{$name} = $full_profile;
    }

    bless( $self, $class );
    return $self;
}

sub run {
    my ( $self, $test_id ) = @_;
    my @accumulator;
    my %counter;
    my %counter_for_progress_indicator;

    my $params;

    my $progress = $self->{_db}->test_progress( $test_id, 1 );

    $params = $self->{_db}->get_test_params( $test_id );

    my %methods = Zonemaster::Engine->all_methods;

    foreach my $module ( keys %methods ) {
        foreach my $method ( @{ $methods{$module} } ) {
            $counter_for_progress_indicator{planned}{ $module . '::' . $method } = $module . '::';
        }
    }

    my ( $domain ) = $params->{domain};
    if ( !$domain ) {
        die "Must give the name of a domain to test.\n";
    }
    $domain = $self->to_idn( $domain );
    my %numeric = Zonemaster::Engine::Logger::Entry->levels();

    # used for progress indicator
    my ( $previous_module, $previous_method ) = ( '', '' );

    # Callback defined here so it closes over the setup above.
    Zonemaster::Engine->logger->callback(
        sub {
            my ( $entry ) = @_;

            # TODO: Make minimum level configurable
            # if ( $entry->numeric_level >= $numeric{INFO} ) {
            #     $log->debug("Adding result entry in database: " . $entry->string);

            #     $self->{_db}->add_result_entry( $test_id, {
            #         timestamp => $entry->timestamp,
            #         module    => $entry->module,
            #         testcase  => $entry->testcase,
            #         tag       => $entry->tag,
            #         level     => $entry->level,
            #         args      => $entry->args // {},
            #     });

            # }

            foreach my $trace ( reverse @{ $entry->trace } ) {
                foreach my $module_method ( keys %{ $counter_for_progress_indicator{planned} } ) {
                    if ( index( $trace->[1], $module_method ) > -1 ) {
                        my $percent_progress = 0;
                        my ( $module ) = ( $module_method =~ /(.+::)[^:]+/ );
                        if ( $previous_module eq $module ) {
                            $counter_for_progress_indicator{executed}{$module_method}++;
                        }
                        elsif ( $previous_module ) {
                            foreach my $planned_module_method ( keys %{ $counter_for_progress_indicator{planned} } ) {
                                $counter_for_progress_indicator{executed}{$planned_module_method}++
                                  if ( $counter_for_progress_indicator{planned}{$planned_module_method} eq
                                    $previous_module );
                            }
                        }
                        $previous_module = $module;

                        if ( $previous_method ne $module_method ) {
                            $percent_progress = sprintf(
                                "%.0f",
                                99 * (
                                    scalar( keys %{ $counter_for_progress_indicator{executed} } ) /
                                      scalar( keys %{ $counter_for_progress_indicator{planned} } )
                                )
                            );
                            $self->{_db}->test_progress( $test_id, $percent_progress );

                            $previous_method = $module_method;
                        }
                    }
                }
            }

            $counter{ uc $entry->level } += 1;
        }
    );

    if ( $params->{nameservers} && @{ $params->{nameservers} } > 0 ) {
        $self->add_fake_delegation( $domain, $params->{nameservers} );
    }

    if ( $params->{ds_info} && @{ $params->{ds_info} } > 0 ) {
        $self->add_fake_ds( $domain, $params->{ds_info} );
    }


    # If the profile parameter has been set in the API, then load a profile
    if ( $params->{profile} ) {
        $params->{profile} = lc($params->{profile});
        if ( defined $self->{_profiles}{ $params->{profile} } ) {
            Zonemaster::Engine::Profile->effective->merge( $self->{_profiles}{ $params->{profile} } );
        }
        else {
            die "The profile [$params->{profile}] is not defined in the backend_config ini file";
        }
    }

    # If IPv4 or IPv6 transport has been explicitly disabled or enabled, then load it after
    # any explicitly set profile has been loaded.
    if (defined $params->{ipv4}) {
        Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, ( $params->{ipv4} ) ? ( 1 ) : ( 0 ) );
    }

    if (defined $params->{ipv6}) {
        Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, ( $params->{ipv6} ) ? ( 1 ) : ( 0 ) );
    }

    # Actually run tests!
    eval { Zonemaster::Engine->test_zone( $domain ); };
    if ( $@ ) {
        my $err = $@;
        if ( blessed $err and $err->isa( "NormalExit" ) ) {
            say STDERR "Exited early: " . $err->message;
        }
        else {
            die "$err\n";    # Don't know what it is, rethrow
        }
    }

    $progress = $self->{_db}->test_progress( $test_id, 100 );

    my @entries = grep { $_->numeric_level >= $numeric{INFO} } @{ Zonemaster::Engine->logger->entries };

    $self->{_db}->add_result_entries( $test_id, \@entries);

    return;
} ## end sub run

sub reset {
    my ( $self ) = @_;
    Zonemaster::Engine->reset();
}

sub add_fake_delegation {
    my ( $self, $domain, $nameservers ) = @_;
    my @ns_with_no_ip;
    my %data;

    foreach my $ns_ip_pair ( @$nameservers ) {
        if ( $ns_ip_pair->{ns} && $ns_ip_pair->{ip} ) {
            push( @{ $data{ $self->to_idn( $ns_ip_pair->{ns} ) } }, $ns_ip_pair->{ip} );
        }
        elsif ($ns_ip_pair->{ns}) {
            push(@ns_with_no_ip, $self->to_idn( $ns_ip_pair->{ns} ) );
        }
        else {
            die "Invalid ns_ip_pair";
        }
    }

    foreach my $ns ( @ns_with_no_ip ) {
        if ( not exists $data{ $ns } ) {
            $data{ $self->to_idn( $ns ) } = undef;
        }
    }

    Zonemaster::Engine->add_fake_delegation( $domain => \%data );

    return;
}

sub add_fake_ds {
    my ( $self, $domain, $ds_info ) = @_;
    my @data;

    foreach my $ds ( @{ $ds_info } ) {
        push @data, { keytag => $ds->{keytag}, algorithm => $ds->{algorithm}, type => $ds->{digtype}, digest => $ds->{digest} };
    }

    Zonemaster::Engine->add_fake_ds( $domain => \@data );

    return;
}

sub to_idn {
    my ( $self, $str ) = @_;

    if ( $str =~ m/^[[:ascii:]]+$/ ) {
        return $str;
    }

    if ( Zonemaster::LDNS::has_idn() ) {
        return Zonemaster::LDNS::to_idn( $str );
    }
    else {
        warn __( "Warning: Zonemaster::LDNS not compiled with libidn, cannot handle non-ASCII names correctly." );
        return $str;
    }
}

1;

package Zonemaster::Backend::TestAgent;
our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;

use Zonemaster::LDNS;

use Zonemaster::Engine;
use Zonemaster::Engine::Translator;
use Zonemaster::Backend::Config;

sub new {
    my ( $class, $params ) = @_;
    my $self = {};

    if ( $params && $params->{db} ) {
        eval "require $params->{db}";
        $self->{db} = "$params->{db}"->new();
    }
    else {
        my $backend_module = "Zonemaster::Backend::DB::" . Zonemaster::Backend::Config->BackendDBType();
        eval "require $backend_module";
        $self->{db} = $backend_module->new();
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

    my $progress = $self->{db}->test_progress( $test_id, 1 );

    $params = $self->{db}->get_test_params( $test_id );

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

    if (defined $params->{ipv4} || defined $params->{ipv6}) {
        Zonemaster::Engine->config->get->{net}{ipv4} = ( $params->{ipv4} ) ? ( 1 ) : ( 0 );
        Zonemaster::Engine->config->get->{net}{ipv6} = ( $params->{ipv6} ) ? ( 1 ) : ( 0 );
    }
    else {
        Zonemaster::Engine->config->get->{net}{ipv4} = 1;
        Zonemaster::Engine->config->get->{net}{ipv6} = 1;
    }

    # used for progress indicator
    my ( $previous_module, $previous_method ) = ( '', '' );

    # Callback defined here so it closes over the setup above.
    Zonemaster::Engine->logger->callback(
        sub {
            my ( $entry ) = @_;

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
                                100 * (
                                    scalar( keys %{ $counter_for_progress_indicator{executed} } ) /
                                      scalar( keys %{ $counter_for_progress_indicator{planned} } )
                                )
                            );
                            $self->{db}->test_progress( $test_id, $percent_progress );

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
        if ( $params->{profile} eq 'test_profile_1' and Zonemaster::Backend::Config->CustomProfilesPath()) {
            # The config has defined an alternative profile and "test_profile_1" has been set.
            Zonemaster::Engine->config->load_policy_file( Zonemaster::Backend::Config->CustomProfilesPath() . '/iana-profile.json' );
        }
        else { # The profile parameter has been set to something else or alternative profile is not defined
            Zonemaster::Engine->config->load_policy_file( 'iana-profile.json' );
        }
        # It will be silently ignored if the file does not exist.
    }


    if ( $params->{config} ) {
        my $config_file_path = Zonemaster::Backend::Config->GetCustomConfigParameter('ZONEMASTER', $params->{config});
        if ($config_file_path) {
            if (-e $config_file_path) {
                Zonemaster::Engine->config->load_config_file( $config_file_path );
            }
            else {
                die "The file specified by the config parameter value: [$params->{config}] doesn't exist";
            }
        }
        else {
            die "Unknown test configuration: [$params->{config}]\n"
        }
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

    $self->{db}->test_results( $test_id, Zonemaster::Engine->logger->json( 'INFO' ) );

    $progress = $self->{db}->test_progress( $test_id );

    return;
} ## end sub run

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

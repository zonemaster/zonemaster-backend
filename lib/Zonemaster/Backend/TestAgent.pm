package Zonemaster::Backend::TestAgent;
our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

use DBI qw(:utils);
use JSON::PP;
use Scalar::Util qw( blessed );
use File::Slurp;

use Zonemaster::LDNS;

use Zonemaster::Engine;
use Zonemaster::Engine::Translator;
use Zonemaster::Backend::Config;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Util;

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
    my ( $self, $test_id, $show_progress ) = @_;
    my @accumulator;

    my $params;

    $params = $self->{_db}->get_test_params( $test_id );

    my ( $domain ) = $params->{domain};
    if ( !$domain ) {
        die "Must give the name of a domain to test.\n";
    }
    $domain = $self->to_idn( $domain );

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

    my %methods = Zonemaster::Engine->all_methods;

    # BASIC methods are always run: Basic0{0..4}
    my $nbr_testcases_planned = 5;
    my $nbr_testcases_finished = 0;

    foreach my $module ( keys %methods ) {
        foreach my $method ( @{ $methods{$module} } ) {
            if ( Zonemaster::Engine::Util::should_run_test( $method ) ) {
                $nbr_testcases_planned++;
            }
        }
    }


    if ( $show_progress ) {
        # Callback defined here so it closes over the setup above.
        Zonemaster::Engine->logger->callback(
            sub {
                my ( $entry ) = @_;
                if ( $entry->{tag} and $entry->{tag} eq 'TEST_CASE_END' ) {
                    $nbr_testcases_finished++;
                    my $progress_percent = 99 * $nbr_testcases_finished /  $nbr_testcases_planned;
                    $self->{_db}->test_progress( $test_id, $progress_percent );
                }
            }
        );
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

    $self->{_db}->store_results( $test_id, Zonemaster::Engine->logger->json( 'INFO' ) );

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
        warn __( "Warning: Zonemaster::LDNS not compiled with libidn2, cannot handle non-ASCII names correctly." );
        return $str;
    }
}

1;

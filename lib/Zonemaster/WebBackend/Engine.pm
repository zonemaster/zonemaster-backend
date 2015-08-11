package Zonemaster::WebBackend::Engine;

our $VERSION = '1.0.2_01';

use strict;
use warnings;
use 5.14.2;

# Public Modules
use JSON;
use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use String::ShellQuote;
use File::Slurp qw(append_file);
use Net::LDNS;
use Net::IP::XS qw(:PROC);
use HTML::Entities;

# Zonemaster Modules
use Zonemaster;
use Zonemaster::Nameserver;
use Zonemaster::DNSName;
use Zonemaster::Recursor;
use Zonemaster::WebBackend::Config;
use Zonemaster::WebBackend::Translator;

my $recursor = Zonemaster::Recursor->new;

sub new {
    my ( $type, $params ) = @_;

    my $self = {};
    bless( $self, $type );

    if ( $params && $params->{db} ) {
        eval {
            eval "require $params->{db}";
            die $@ if $@;
            $self->{db} = "$params->{db}"->new();
        };
        die $@ if $@;
    }
    else {
        eval {
            my $backend_module = "Zonemaster::WebBackend::DB::" . Zonemaster::WebBackend::Config->BackendDBType();
            eval "require $backend_module";
            die $@ if $@;
            $self->{db} = $backend_module->new();
        };
        die $@ if $@;
    }

    return ( $self );
}

sub version_info {
    my ( $self ) = @_;

    my %ver;
    $ver{zonemaster_engine} = Zonemaster->VERSION;
    $ver{zonemaster_backend} = Zonemaster::WebBackend::Engine->VERSION;

    return \%ver;
}

sub get_ns_ips {
    my ( $self, $ns_name ) = @_;

    my @adresses = map { {$ns_name => $_->short} } $recursor->get_addresses_for($ns_name);
    @adresses = { $ns_name => '0.0.0.0' } if not @adresses;

    return \@adresses;
}

sub get_data_from_parent_zone {
    my ( $self, $domain ) = @_;

    my %result;

    my ( $dn, $dn_syntax ) = $self->_check_domain( $domain, 'Domain name' );
    return $dn_syntax if ( $dn_syntax->{status} eq 'nok' );

    my @ns_list;
    my @ns_names;

    my $zone = Zonemaster->zone( $domain );
    push @ns_list, { ns => $_->name->string, ip => $_->address->short} for @{$zone->glue};

    my %algorithm_ids = ( 1 => 'sha1', 2 => 'sha256', 3 => 'ghost', 4 => 'sha384' );
    my @ds_list;

    $zone = Zonemaster->zone($domain);
    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1, cd => 1, recurse => 1 } );
    if ($ds_p) {
		my @ds = $ds_p->get_records( 'DS', 'answer' );

		foreach my $ds ( @ds ) {
            next unless $ds->type eq 'DS';
			if ( $algorithm_ids{ $ds->digtype } ) {
				push(@ds_list, { algorithm => $algorithm_ids{$ds->digtype}, digest => $ds->hexdigest, keytag => $ds->keytag });
			}
		} 
	}

    $result{ns_list} = \@ns_list;
    $result{ds_list} = \@ds_list;

    return \%result;
}

sub _check_domain {
    my ( $self, $dn, $type ) = @_;

    if ( !defined( $dn ) ) {
        return ( $dn, { status => 'nok', message => encode_entities( "$type required" ) } );
    }

    if ( $dn =~ m/[^[:ascii:]]+/ ) {
        if ( Net::LDNS::has_idn() ) {
            eval { $dn = Net::LDNS::to_idn( $dn ); };
            if ( $@ ) {
                return (
                    $dn,
                    {
                        status  => 'nok',
                        message => encode_entities( "The domain name cannot be converted to the IDN format" )
                    }
                );
            }
        }
        else {
            return (
                $dn,
                {
                    status => 'nok',
                    message =>
                      encode_entities( "$type contains non-ascii characters and IDN conversion is not installed" )
                }
            );
        }
    }

    my @res;
    @res = Zonemaster::Test::Basic->basic00($dn);
    if (@res != 0) {
        return ( $dn, { status => 'nok', message => encode_entities( "$type name or label outside allowed length" ) } );
    }

    @res = Zonemaster::Test::Syntax->syntax01($dn);
    if (not grep {$_->tag eq 'ONLY_ALLOWED_CHARS'} @res) {
        return ( $dn, { status => 'nok', message => encode_entities( "$type name contains non-allowed character(s)" ) } );
    }

    @res = Zonemaster::Test::Syntax->syntax02($dn);
    if (not grep {$_->tag eq 'NO_ENDING_HYPHENS'} @res) {
        return ( $dn, { status => 'nok', message => encode_entities( "$type label must not start or end with a hyphen" ) } );
    }

    return ( $dn, { status => 'ok', message => 'Syntax ok' } );
}

sub validate_syntax {
    my ( $self, $syntax_input ) = @_;

    my @allowed_params_keys = (
        'domain',   'ipv4',      'ipv6', 'ds_digest_pairs', 'nameservers', 'profile',
        'advanced', 'client_id', 'client_version', 'user_ip', 'user_location_info'
    );

    foreach my $k ( keys %$syntax_input ) {
        return { status => 'nok', message => encode_entities( "Unknown option in parameters" ) }
          unless ( grep { $_ eq $k } @allowed_params_keys );
    }

    if ( ( defined $syntax_input->{nameservers} && @{ $syntax_input->{nameservers} } ) ) {
        foreach my $ns_ip ( @{ $syntax_input->{nameservers} } ) {
            foreach my $k ( keys %$ns_ip ) {
                delete( $ns_ip->{$k} ) unless ( $k eq 'ns' || $k eq 'ip' );
            }
        }
    }

    if ( ( defined $syntax_input->{ds_digest_pairs} && @{ $syntax_input->{ds_digest_pairs} } ) ) {
        foreach my $ds_digest ( @{ $syntax_input->{ds_digest_pairs} } ) {
            foreach my $k ( keys %$ds_digest ) {
                delete( $ds_digest->{$k} ) unless ( $k eq 'algorithm' || $k eq 'digest' );
            }
        }
    }

    return { status => 'nok', message => encode_entities( "At least one transport protocol required (IPv4 or IPv6)" ) }
      unless ( $syntax_input->{ipv4} || $syntax_input->{ipv6} );

    if ( defined $syntax_input->{advanced} ) {
        return { status => 'nok', message => encode_entities( "Invalid 'advanced' option format" ) }
          unless ( $syntax_input->{advanced} ne JSON::false || $syntax_input->{advanced} ne JSON::true );
    }

    if ( defined $syntax_input->{ipv4} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv4 transport option format" ) }
          unless ( $syntax_input->{ipv4} ne JSON::false
            || $syntax_input->{ipv4} ne JSON::true
            || $syntax_input->{ipv4} ne '1'
            || $syntax_input->{ipv4} ne '0' );
    }

    if ( defined $syntax_input->{ipv6} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv6 transport option format" ) }
          unless ( $syntax_input->{ipv6} ne JSON::false
            || $syntax_input->{ipv6} ne JSON::true
            || $syntax_input->{ipv6} ne '1'
            || $syntax_input->{ipv6} ne '0' );
    }

    if ( defined $syntax_input->{profile} ) {
        return { status => 'nok', message => encode_entities( "Invalid profile option format" ) }
          unless ( $syntax_input->{profile} ne 'default_profile'
            || $syntax_input->{profile} ne 'test_profile_1'
            || $syntax_input->{profile} ne 'test_profile_2' );
    }

    my ( $dn, $dn_syntax ) = $self->_check_domain( $syntax_input->{domain}, 'Domain name' );

    return $dn_syntax if ( $dn_syntax->{status} eq 'nok' );

    if ( defined $syntax_input->{nameservers} && @{ $syntax_input->{nameservers} } ) {
        foreach my $ns_ip ( @{ $syntax_input->{nameservers} } ) {
            my ( $ns, $ns_syntax ) = $self->_check_domain( $ns_ip->{ns}, "NS [$ns_ip->{ns}]" );
            return $ns_syntax if ( $ns_syntax->{status} eq 'nok' );
        }

        foreach my $ns_ip ( @{ $syntax_input->{nameservers} } ) {
            return { status => 'nok', message => encode_entities( "Invalid IP address: [$ns_ip->{ip}]" ) }
              unless ( ip_is_ipv4( $ns_ip->{ip} ) || ip_is_ipv6( $ns_ip->{ip} ) );
        }

        foreach my $ds_digest ( @{ $syntax_input->{ds_digest_pairs} } ) {
            return {
                status  => 'nok',
                message => encode_entities( "Invalid algorithm type: [$ds_digest->{algorithm}]" )
              }
              unless ( $ds_digest->{algorithm} eq 'sha1' || $ds_digest->{algorithm} eq 'sha256' );
        }

        foreach my $ds_digest ( @{ $syntax_input->{ds_digest_pairs} } ) {
            if ( $ds_digest->{algorithm} eq 'sha1' ) {
                return {
                    status  => 'nok',
                    message => encode_entities( "Invalid digest format: [$ds_digest->{digest}]" )
                  }
                  if ( length( $ds_digest->{digest} ) != 40 || $ds_digest->{digest} =~ /[^A-Fa-f0-9]/ );
            }
            elsif ( $ds_digest->{algorithm} eq 'sha256' ) {
                return {
                    status  => 'nok',
                    message => encode_entities( "Invalid digest format: [$ds_digest->{digest}]" )
                  }
                  if ( length( $ds_digest->{digest} ) != 64 || $ds_digest->{digest} =~ /[^A-Fa-f0-9]/ );
            }
        }
    }

    return { status => 'ok', message => encode_entities( 'Syntax ok' ) };
}

sub add_user_ip_geolocation {
    my ( $self, $params ) = @_;
    
	if ($params->{user_ip} 
		&& Zonemaster::WebBackend::Config->Maxmind_ISP_DB_File()
		&& Zonemaster::WebBackend::Config->Maxmind_City_DB_File()
	) {
		my $ip = new Net::IP::XS($params->{user_ip});
		if ($ip->iptype() eq 'PUBLIC') {
			require Geo::IP;
			my $gi = Geo::IP->new(Zonemaster::WebBackend::Config->Maxmind_ISP_DB_File());
			my $isp = $gi->isp_by_addr($params->{user_ip});
			
			require GeoIP2::Database::Reader;
			my $reader = GeoIP2::Database::Reader->new(file => Zonemaster::WebBackend::Config->Maxmind_City_DB_File());
	
			my $city = $reader->city(ip => $params->{user_ip});

			$params->{user_location_info}->{isp} = $isp;
			$params->{user_location_info}->{country} = $city->country()->name();
			$params->{user_location_info}->{city} = $city->city()->name();
			$params->{user_location_info}->{longitude} = $city->location()->longitude();
			$params->{user_location_info}->{latitude} = $city->location()->latitude();
		}
		else {
			$params->{user_location_info}->{isp} = "Private IP address";
		}
	}
}

sub start_domain_test {
    my ( $self, $params ) = @_;
    my $result = 0;

    $params->{domain} =~ s/^\.// unless ( !$params->{domain} || $params->{domain} eq '.' );
    my $syntax_result = $self->validate_syntax( $params );
    die $syntax_result->{message} unless ( $syntax_result && $syntax_result->{status} eq 'ok' );

    die "No domain in parameters\n" unless ( $params->{domain} );
    
    $self->add_user_ip_geolocation($params);

    $result = $self->{db}->create_new_test( $params->{domain}, $params, 10, 10 );

    return $result;
}

sub test_progress {
    my ( $self, $test_id ) = @_;

    my $result = 0;

    $result = $self->{db}->test_progress( $test_id );

    return $result;
}

sub get_test_params {
    my ( $self, $test_id ) = @_;

    my $result = 0;

    $result = $self->{db}->get_test_params( $test_id );

    return $result;
}

sub get_test_results {
    my ( $self, $params ) = @_;
    my $result;

    #	my $syntax_result = $self->validate_syntax($params);
    #	die $syntax_result->{message} unless ($syntax_result && $syntax_result->{status} eq 'ok');

    my $translator;
    $translator = Zonemaster::WebBackend::Translator->new;
    my ( $browser_lang ) = ( $params->{language} =~ /^(\w{2})/ );

    eval { $translator->data } if $translator;    # Provoke lazy loading of translation data

    my $test_info = $self->{db}->test_results( $params->{id} );
    my @zm_results;
    foreach my $test_res ( @{ $test_info->{results} } ) {
        my $res;
        if ( $test_res->{module} eq 'NAMESERVER' ) {
            $res->{ns} = ( $test_res->{args}->{ns} ) ? ( $test_res->{args}->{ns} ) : ( 'All' );
        }
        elsif ($test_res->{module} eq 'SYSTEM'
            && $test_res->{tag} eq 'POLICY_DISABLED'
            && $test_res->{args}->{name} eq 'Example' )
        {
            next;
        }

        $res->{module} = $test_res->{module};
        $res->{message} = $translator->translate_tag( $test_res, $browser_lang ) . "\n";
        $res->{message} =~ s/,/, /isg;
        $res->{message} =~ s/;/; /isg;
        $res->{level} = $test_res->{level};

        if ( $test_res->{module} eq 'SYSTEM' ) {
            if ( $res->{message} =~ /policy\.json/ ) {
                my ( $policy ) = ( $res->{message} =~ /\s(\/.*)$/ );
                my $policy_description = 'DEFAULT POLICY';
                $policy_description = 'SOME OTHER POLICY' if ( $policy =~ /some\/other\/policy\path/ );
                $res->{message} =~ s/$policy/$policy_description/;
            }
            elsif ( $res->{message} =~ /config\.json/ ) {
                my ( $config ) = ( $res->{message} =~ /\s(\/.*)$/ );
                my $config_description = 'DEFAULT CONFIGURATION';
                $config_description = 'SOME OTHER CONFIGURATION' if ( $config =~ /some\/other\/configuration\path/ );
                $res->{message} =~ s/$config/$config_description/;
            }
        }

        push( @zm_results, $res );
    }

    $result = $test_info;
    $result->{results} = \@zm_results;

    return $result;
}

sub get_test_history {
    my ( $self, $p ) = @_;

    my $results = $self->{db}->get_test_history( $p );

    return $results;
}

sub add_api_user {
    my ( $self, $params, $procedure, $remote_ip ) = @_;
    my $result;

    my $allow = 0;
    if ( defined $procedure && defined $remote_ip ) {
        $allow = 1 if ( $remote_ip eq '::1' );
    }
    else {
        $allow = 1;
    }

    if ( $allow ) {
        $result = $self->{db}->add_api_user( $params );
    }
}

sub add_batch_job {
    my ( $self, $params ) = @_;
    my $batch_id;

    if ( $self->{db}->user_authorized( $params->{username}, $params->{api_key} ) ) {
        $params->{batch_params}->{client_id}      = 'Zonemaster Batch Scheduler';
        $params->{batch_params}->{client_version} = '1.0';

        my $domains = $params->{batch_params}->{domains};
        delete( $params->{batch_params}->{domains} );

        $batch_id = $self->{db}->create_new_batch_job( $params->{username} );

        my $minutes_between_tests_with_same_params = 5;
        foreach my $domain ( @{$domains} ) {
            $self->{db}
              ->create_new_test( $domain, $params->{batch_params}, $minutes_between_tests_with_same_params, $batch_id );
        }
    }
    else {
        die "User $params->{username} not authorized to use batch mode\n";
    }

    return $batch_id;
}

sub api1 {
    my ( $self, $p ) = @_;

    return "$]";
}

1;

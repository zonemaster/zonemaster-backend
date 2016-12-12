package Zonemaster::WebBackend::Engine;

our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

# Public Modules
use JSON::PP;
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

    my @ds_list;

    $zone = Zonemaster->zone($domain);
    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1, cd => 1, recurse => 1 } );
    if ($ds_p) {
		my @ds = $ds_p->get_records( 'DS', 'answer' );

		foreach my $ds ( @ds ) {
            next unless $ds->type eq 'DS';
			push(@ds_list, { keytag => $ds->keytag, algorithm => $ds->algorithm, digtype => $ds->digtype, digest => $ds->hexdigest });
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

    return ( $dn, { status => 'ok', message => 'Syntax ok' } );
}

sub validate_syntax {
    my ( $self, $syntax_input ) = @_;

    my @allowed_params_keys = (
        'domain',   'ipv4',      'ipv6', 'ds_info', 'nameservers', 'profile',
        'advanced', 'client_id', 'client_version', 'user_ip', 'user_location_info', 'config', 'priority', 'queue'
    );

    foreach my $k ( keys %$syntax_input ) {
        return { status => 'nok', message => encode_entities( "Unknown option [$k] in parameters" ) }
          unless ( grep { $_ eq $k } @allowed_params_keys );
    }

    if ( ( defined $syntax_input->{nameservers} && @{ $syntax_input->{nameservers} } ) ) {
        foreach my $ns_ip ( @{ $syntax_input->{nameservers} } ) {
            foreach my $k ( keys %$ns_ip ) {
                delete( $ns_ip->{$k} ) unless ( $k eq 'ns' || $k eq 'ip' );
            }
        }
    }

    if ( ( defined $syntax_input->{ds_info} && @{ $syntax_input->{ds_info} } ) ) {
        foreach my $ds_digest ( @{ $syntax_input->{ds_info} } ) {
            foreach my $k ( keys %$ds_digest ) {
                delete( $ds_digest->{$k} ) unless ( $k eq 'algorithm' || $k eq 'digest' || $k eq 'digtype' || $k eq 'keytag' );
            }
        }
    }

    if ( defined $syntax_input->{advanced} ) {
        return { status => 'nok', message => encode_entities( "Invalid 'advanced' option format" ) }
          unless ( $syntax_input->{advanced} eq JSON::false || $syntax_input->{advanced} eq JSON::true );
    }

    if ( defined $syntax_input->{ipv4} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv4 transport option format" ) }
          unless ( $syntax_input->{ipv4} eq JSON::false
            || $syntax_input->{ipv4} eq JSON::true
            || $syntax_input->{ipv4} eq '1'
            || $syntax_input->{ipv4} eq '0' );
    }

    if ( defined $syntax_input->{ipv6} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv6 transport option format" ) }
          unless ( $syntax_input->{ipv6} eq JSON::false
            || $syntax_input->{ipv6} eq JSON::true
            || $syntax_input->{ipv6} eq '1'
            || $syntax_input->{ipv6} eq '0' );
    }

    if ( defined $syntax_input->{profile} ) {
        return { status => 'nok', message => encode_entities( "Invalid profile option format" ) }
          unless ( $syntax_input->{profile} eq 'default_profile'
            || $syntax_input->{profile} eq 'test_profile_1'
            || $syntax_input->{profile} eq 'test_profile_2' );
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
              unless ( !$ns_ip->{ip} || ip_is_ipv4( $ns_ip->{ip} ) || ip_is_ipv6( $ns_ip->{ip} ) );
        }

        foreach my $ds_digest ( @{ $syntax_input->{ds_info} } ) {
            return {
                status  => 'nok',
                message => encode_entities( "Invalid algorithm type: [$ds_digest->{algorithm}]" )
              }
              if ( $ds_digest->{algorithm} =~ /\D/ );
        }

        foreach my $ds_digest ( @{ $syntax_input->{ds_info} } ) {
			return {
				status  => 'nok',
				message => encode_entities( "Invalid digest format: [$ds_digest->{digest}]" )
			}
			if ( ( length( $ds_digest->{digest} ) != 64 && length( $ds_digest->{digest} ) != 40 ) || $ds_digest->{digest} =~ /[^A-Fa-f0-9]/ );
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
    
    if ($params->{config}) {
		$params->{config} =~ s/[^\w_]//isg;
		die "Unknown test configuration: [$params->{config}]\n" unless ( Zonemaster::WebBackend::Config->GetCustomConfigParameter('ZONEMASTER', $params->{config}) );
	}
    
    $self->add_user_ip_geolocation($params);

    $result = $self->{db}->create_new_test( $params->{domain}, $params, 10 );

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
                $policy_description = 'SOME OTHER POLICY' if ( $policy =~ /some\/other\/policy\/path/ );
                $res->{message} =~ s/$policy/$policy_description/;
            }
            elsif ( $res->{message} =~ /config\.json/ ) {
                my ( $config ) = ( $res->{message} =~ /\s(\/.*)$/ );
                my $config_description = 'DEFAULT CONFIGURATION';
                $config_description = 'SOME OTHER CONFIGURATION' if ( $config =~ /some\/other\/configuration\/path/ );
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
    my ( $self, $p, undef, $remote_ip ) = @_;
    my $result = 0;

    my $allow = 0;
    if ( defined $remote_ip ) {
        $allow = 1 if ( $remote_ip eq '::1' || $remote_ip eq '127.0.0.1' );
    }
    else {
        $allow = 1;
    }

    if ( $allow ) {
		$result = 1 if ( $self->{db}->add_api_user( $p->{username}, $p->{api_key} ) eq '1' );
    }
    
    return $result;
}

=coment
sub add_batch_job {
    my ( $self, $params ) = @_;
    my $batch_id;

    if ( $self->{db}->user_authorized( $params->{username}, $params->{api_key} ) ) {
        $params->{test_params}->{client_id}      = 'Zonemaster Batch Scheduler';
        $params->{test_params}->{client_version} = '1.0';
        $params->{test_params}->{priority} = 5 unless (defined $params->{test_params}->{priority});

        $batch_id = $self->{db}->create_new_batch_job( $params->{username} );

        my $minutes_between_tests_with_same_params = 5;
#        $self->{db}->dbhandle->begin_work();
        foreach my $domain ( @{$params->{domains}} ) {
            $self->{db}
              ->create_new_test( $domain, $params->{test_params}, 5, $batch_id );
        }
#        $self->{db}->dbhandle->commit();
    }
    else {
        die "User $params->{username} not authorized to use batch mode\n";
    }

    return $batch_id;
}
=cut

sub add_batch_job {
    my ( $self, $params ) = @_;

    my $results = $self->{db}->add_batch_job( $params );

    return $results;
}


sub get_batch_job_result {
    my ( $self, $batch_id ) = @_;

    return $self->{db}->get_batch_job_result($batch_id);
}
1;

package Zonemaster::Backend::RPCAPI;

use strict;
use warnings;
use 5.14.2;

# Public Modules
use JSON::PP;
use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use String::ShellQuote;
use File::Slurp qw(append_file);
use Zonemaster::LDNS;
use Net::IP::XS qw(:PROC);
use HTML::Entities;
use JSON::Validator "joi";

# Zonemaster Modules
use Zonemaster::Engine;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Recursor;
use Zonemaster::Backend;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::Translator;
use Zonemaster::Backend::Validator;

my $zm_validator = Zonemaster::Backend::Validator->new;
my %json_schemas;
my $recursor = Zonemaster::Engine::Recursor->new;

sub new {
    my ( $type, $params ) = @_;

    my $self = {};
    bless( $self, $type );

    my $config = Zonemaster::Backend::Config->load_config();

    if ( $params && $params->{db} ) {
        eval {
            eval "require $params->{db}";
            die "$@ \n" if $@;
            $self->{db} = "$params->{db}"->new( { config => $config } );
        };
        die "$@ \n" if $@;
    }
    else {
        eval {
            my $backend_module = "Zonemaster::Backend::DB::" . $config->BackendDBType();
            eval "require $backend_module";
            die "$@ \n" if $@;
            $self->{db} = $backend_module->new( { config => $config } );
        };
        die "$@ \n" if $@;
    }

    return ( $self );
}

$json_schemas{version_info} = joi->object->strict;
sub version_info {
    my ( $self ) = @_;

    my %ver;
    $ver{zonemaster_engine} = Zonemaster::Engine->VERSION;
    $ver{zonemaster_backend} = Zonemaster::Backend->VERSION;

    return \%ver;
}

$json_schemas{profile_names} = joi->object->strict;
sub profile_names {
    my ($self) = @_;

    my @profiles = Zonemaster::Backend::Config->load_config()->ListPublicProfiles();

    return \@profiles;
}

$json_schemas{get_host_by_name} = joi->object->strict->props(
    hostname   => $zm_validator->domain_name->required
);
sub get_host_by_name {
    my ( $self, $params ) = @_;
    my $ns_name  = $params->{"hostname"};

    my @adresses = map { {$ns_name => $_->short} } $recursor->get_addresses_for($ns_name);
    @adresses = { $ns_name => '0.0.0.0' } if not @adresses;

    return \@adresses;

}

$json_schemas{get_data_from_parent_zone} = joi->object->strict->props(
    domain   => $zm_validator->domain_name->required
);
sub get_data_from_parent_zone {
    my ( $self, $params ) = @_;
    my $domain = "";

    if (ref \$params eq "SCALAR") {
        $domain = $params;
    } else {
        $domain = $params->{"domain"};
    }

    my %result;

    my ( $dn, $dn_syntax ) = $self->_check_domain( $domain, 'Domain name' );
    return $dn_syntax if ( $dn_syntax->{status} eq 'nok' );

    my @ns_list;
    my @ns_names;

    my $zone = Zonemaster::Engine->zone( $domain );
    push @ns_list, { ns => $_->name->string, ip => $_->address->short} for @{$zone->glue};

    my @ds_list;

    $zone = Zonemaster::Engine->zone($domain);
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
        if ( Zonemaster::LDNS::has_idn() ) {
            eval { $dn = Zonemaster::LDNS::to_idn( $dn ); };
            if ( $@ ) {
                return (
                    $dn,
                    {
                        status  => 'nok',
                        message => encode_entities( "The domain name is not a valid IDNA string and cannot be converted to an A-label" )
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
                      encode_entities( "$type contains non-ascii characters and IDNA conversion is not installed" )
                }
            );
        }
    }

    if( $dn !~ m/^[\-a-zA-Z0-9\.\_]+$/ ) {
	    return (
		   $dn,
		   {
			   status  => 'nok',
			   message => encode_entities( "The domain name contains unauthorized character(s)")
                   }
            );
    }

    my @res;
    @res = Zonemaster::Engine::Test::Basic->basic00($dn);
    if (@res != 0) {
        return ( $dn, { status => 'nok', message => encode_entities( "$type name or label outside allowed length" ) } );
    }

    return ( $dn, { status => 'ok', message => 'Syntax ok' } );
}

sub validate_syntax {
    my ( $self, $syntax_input ) = @_;

    my @allowed_params_keys = (
        'domain',   'ipv4',      'ipv6', 'ds_info', 'nameservers', 'profile',
        'client_id', 'client_version', 'config', 'priority', 'queue'
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

    if ( defined $syntax_input->{ipv4} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv4 transport option format" ) }
          unless ( $syntax_input->{ipv4} eq JSON::PP::false
            || $syntax_input->{ipv4} eq JSON::PP::true
            || $syntax_input->{ipv4} eq '1'
            || $syntax_input->{ipv4} eq '0' );
    }

    if ( defined $syntax_input->{ipv6} ) {
        return { status => 'nok', message => encode_entities( "Invalid IPv6 transport option format" ) }
          unless ( $syntax_input->{ipv6} eq JSON::PP::false
            || $syntax_input->{ipv6} eq JSON::PP::true
            || $syntax_input->{ipv6} eq '1'
            || $syntax_input->{ipv6} eq '0' );
    }

    if ( defined $syntax_input->{profile} ) {
        my @profiles = map lc, Zonemaster::Backend::Config->load_config()->ListPublicProfiles();
        return { status => 'nok', message => encode_entities( "Invalid profile option format" ) }
          unless ( grep { $_ eq lc $syntax_input->{profile} } @profiles );
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
                unless( !$ns_ip->{ip} || $ns_ip->{ip} =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ || $ns_ip->{ip} =~ /^([0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)|([0-9A-Fa-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/);

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
            if (
                ( length( $ds_digest->{digest} ) != 96 &&
                      length( $ds_digest->{digest} ) != 64 &&
                      length( $ds_digest->{digest} ) != 40 ) ||
                      $ds_digest->{digest} =~ /[^A-Fa-f0-9]/
            );
        }
    }

    return { status => 'ok', message => encode_entities( 'Syntax ok' ) };
}

$json_schemas{start_domain_test} = joi->object->strict->props(
    domain => $zm_validator->domain_name->required,
    ipv4 => joi->boolean,
    ipv6 => joi->boolean,
    nameservers => joi->array->items(
        $zm_validator->nameserver
    ),
    ds_info => joi->array->items(
        $zm_validator->ds_info
    ),
    profile => $zm_validator->profile_name,
    client_id => $zm_validator->client_id,
    client_version => $zm_validator->client_version,
    config => joi->string,
    priority => $zm_validator->priority,
    queue => $zm_validator->queue
);
sub start_domain_test {
    my ( $self, $params ) = @_;

    my $result = 0;

    $params->{domain} =~ s/^\.// unless ( !$params->{domain} || $params->{domain} eq '.' );
    my $syntax_result = $self->validate_syntax( $params );
    die "$syntax_result->{message} \n" unless ( $syntax_result && $syntax_result->{status} eq 'ok' );

    die "No domain in parameters\n" unless ( $params->{domain} );

    if ($params->{config}) {
        $params->{config} =~ s/[^\w_]//isg;
        die "Unknown test configuration: [$params->{config}]\n" unless ( Zonemaster::Backend::Config->load_config()->GetCustomConfigParameter('ZONEMASTER', $params->{config}) );
    }

    $params->{priority}  //= 10;
    $params->{queue}     //= 0;
    my $minutes_between_tests_with_same_params = 10;

    $result = $self->{db}->create_new_test( $params->{domain}, $params, $minutes_between_tests_with_same_params );

    return $result;
}

$json_schemas{test_progress} = joi->object->strict->props(
    test_id => $zm_validator->test_id->required
);
sub test_progress {
    my ( $self, $params ) = @_;
    my $test_id = "";
    if (ref \$params eq "SCALAR") {
        $test_id = $params;
    } else {
        $test_id = $params->{"test_id"};
    }

    my $result = 0;

    $result = $self->{db}->test_progress( $test_id );

    return $result;
}

$json_schemas{get_test_params} = joi->object->strict->props(
    test_id => $zm_validator->test_id->required
);
sub get_test_params {
    my ( $self, $params ) = @_;
    my $test_id = $params->{"test_id"};

    my $result = 0;

    $result = $self->{db}->get_test_params( $test_id );

    return $result;
}

$json_schemas{get_test_results} = joi->object->strict->props(
    id => $zm_validator->test_id->required,
    language => $zm_validator->translation_language->required
);
sub get_test_results {
    my ( $self, $params ) = @_;

    my $result;

    my $translator;
    $translator = Zonemaster::Backend::Translator->new;
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
                if ( $policy ) {
                    my $policy_description = 'DEFAULT POLICY';
                    $policy_description = 'SOME OTHER POLICY' if ( $policy =~ /some\/other\/policy\/path/ );
                    $res->{message} =~ s/$policy/$policy_description/;
                }
                else {
                    $res->{message} = 'UNKNOWN POLICY FORMAT';
                }
            }
            elsif ( $res->{message} =~ /config\.json/ ) {
                my ( $config ) = ( $res->{message} =~ /\s(\/.*)$/ );
                if ( $config ) {
                    my $config_description = 'DEFAULT CONFIGURATION';
                    $config_description = 'SOME OTHER CONFIGURATION' if ( $config =~ /some\/other\/configuration\/path/ );
                    $res->{message} =~ s/$config/$config_description/;
                }
                else {
                    $res->{message} = 'UNKNOWN CONFIG FORMAT';
                }
            }
        }

        push( @zm_results, $res );
    }

    $result = $test_info;
    $result->{results} = \@zm_results;

    return $result;
}

$json_schemas{get_test_history} = joi->object->strict->props(
    offset => joi->integer->min(0),
    limit => joi->integer->min(0),
    filter => joi->string->regex('^(?:all|delegated|undelegated)$'),
    frontend_params => joi->object->strict->props(
        domain => $zm_validator->domain_name->required
    )->required
);
sub get_test_history {
    my ( $self, $p ) = @_;

    my $results;

    $p->{offset} //= 0;
    $p->{limit} //= 200;
    $p->{filter} //= "all";

    $results = $self->{db}->get_test_history( $p );

    return $results;
}

$json_schemas{add_api_user} = joi->object->strict->props(
    username => $zm_validator->username->required,
    api_key => $zm_validator->api_key->required,
);
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

$json_schemas{add_batch_job} = joi->object->strict->props(
    username => $zm_validator->username->required,
    api_key => $zm_validator->api_key->required,
    domains => joi->array->strict->items(
        $zm_validator->domain_name->required
    )->required,
    test_params => joi->object->strict->props(
        ipv4 => joi->boolean,
        ipv6 => joi->boolean,
        nameservers => joi->array->strict->items(
            $zm_validator->nameserver
        ),
        ds_info => joi->array->strict->items(
            $zm_validator->ds_info
        ),
        profile => $zm_validator->profile_name,
        client_id => $zm_validator->client_id,
        client_version => $zm_validator->client_version,
        config => joi->string,
        priority => $zm_validator->priority,
        queue => $zm_validator->queue
    )
);
sub add_batch_job {
    my ( $self, $params ) = @_;

    $params->{test_params}->{priority}  //= 5;
    $params->{test_params}->{queue}     //= 0;

    my $results = $self->{db}->add_batch_job( $params );

    return $results;
}

$json_schemas{get_batch_job_result} = joi->object->strict->props(
    batch_id => $zm_validator->batch_id->required
);
sub get_batch_job_result {
    my ( $self, $params ) = @_;

    my $batch_id = $params->{"batch_id"};

    return $self->{db}->get_batch_job_result($batch_id);
}

my $rpc_request = joi->object->props(
    jsonrpc => joi->string->required,
    method => $zm_validator->jsonrpc_method()->required);
sub jsonrpc_validate {
    my ( $self, $jsonrpc_request) = @_;

    my @error_rpc = $rpc_request->validate($jsonrpc_request);
    if (!exists $jsonrpc_request->{"id"} || @error_rpc) {
        return {
            jsonrpc => '2.0',
            id => undef,
            error => {
                code => '-32600',
                message=> 'The JSON sent is not a valid request object.',
                data => "@error_rpc\n"
            }
        }
    }

    if (exists $jsonrpc_request->{"params"}) {

        my @error = $json_schemas{$jsonrpc_request->{"method"}}->validate($jsonrpc_request->{"params"});
        return {
                jsonrpc => '2.0',
                id => undef,
                error => {
                    code => '-32602',
                    message=> 'Invalid method parameter(s).',
                    data => "@error\n"
                }
            } if @error;
    }
    return '';
}
1;

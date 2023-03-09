package Zonemaster::Backend::RPCAPI;

use strict;
use warnings;
use 5.14.2;

# Public Modules
use DBI qw(:utils);
use Digest::MD5 qw(md5_hex);
use File::Slurp qw(append_file);
use HTML::Entities;
use JSON::PP;
use JSON::Validator::Joi;
use Log::Any qw($log);
use String::ShellQuote;
use Mojo::JSON::Pointer;
use Scalar::Util qw(blessed);
use JSON::Validator::Schema::Draft7;
use Locale::TextDomain qw[Zonemaster-Backend];
use Locale::Messages qw[LC_MESSAGES LC_ALL];
use POSIX qw (setlocale);
use Encode;

# Zonemaster Modules
use Zonemaster::Engine;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Recursor;
use Zonemaster::Backend;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::Translator;
use Zonemaster::Backend::Validator;
use Zonemaster::Backend::Errors;

my $zm_validator = Zonemaster::Backend::Validator->new;
our %json_schemas;
my $recursor = Zonemaster::Engine::Recursor->new;

sub joi {
    return JSON::Validator::Joi->new;
}

sub new {
    my ( $type, $params ) = @_;

    my $self = {};
    bless( $self, $type );

    if ( ! $params || ! $params->{config} ) {
        handle_exception("Missing 'config' parameter");
    }

    $self->{config} = $params->{config};

    my $dbtype;
    if ( $params->{dbtype} ) {
        $dbtype = $self->{config}->check_db($params->{dbtype});
    } else {
        $dbtype = $self->{config}->DB_engine;
    }

    $self->_init_db($dbtype);

    $self->{_profiles} = Zonemaster::Backend::Config->load_profiles(    #
        $self->{config}->PUBLIC_PROFILES,
        $self->{config}->PRIVATE_PROFILES,
    );

    return ( $self );
}

sub _init_db {
    my ( $self, $dbtype ) = @_;

    eval {
        my $dbclass = Zonemaster::Backend::DB->get_db_class( $dbtype );
        $self->{db} = $dbclass->from_config( $self->{config} );
    };

    if ($@) {
        handle_exception("Failed to initialize the [$dbtype] database backend module: [$@]");
    }
}

sub handle_exception {
    my ( $exception ) = @_;

    if ( !$exception->isa('Zonemaster::Backend::Error') ) {
        my $reason = $exception;
        $exception = Zonemaster::Backend::Error::Internal->new( reason => $reason );
    }

    my $log_extra = $exception->as_hash;
    delete $log_extra->{message};

    if ( $exception->isa('Zonemaster::Backend::Error::Internal') ) {
        $log->error($exception->as_string, $log_extra);
    } else {
        $log->info($exception->as_string, $log_extra);
    }

    die $exception->as_hash;
}

$json_schemas{system_versions} = joi->object->strict;
sub system_versions {
    my ( $self ) = @_;

    my %ver;
    eval {
        $ver{zonemaster_ldns} = Zonemaster::LDNS->VERSION;
        $ver{zonemaster_engine} = Zonemaster::Engine->VERSION;
        $ver{zonemaster_backend} = Zonemaster::Backend->VERSION;
    };
    if ($@) {
        handle_exception( $@ );
    }

    return \%ver;
}

# Deprecated
$json_schemas{version_info} = $json_schemas{system_versions};
sub version_info {
    return system_versions( @_ );
}

$json_schemas{conf_profiles} = joi->object->strict;
sub conf_profiles {
    my ( $self ) = @_;

    my %profiles;
    eval { %profiles = $self->{config}->PUBLIC_PROFILES };
    if ( $@ ) {
        handle_exception( $@ );
    }

    my $result = {
        profiles => [ keys %profiles ]
    };
    return $result;
}

# Deprecated
$json_schemas{profile_names} = $json_schemas{conf_profiles};
sub profile_names {
    my $result = conf_profiles( @_ );
    return $result->{profiles};
}

# Return the list of language tags supported by get_test_results(). The tags are
# derived from the locale tags set in the configuration file.
$json_schemas{conf_languages} = joi->object->strict;
sub conf_languages {
    my ( $self ) = @_;

    my @lang_tags;
    eval {
        my %locales = $self->{config}->LANGUAGE_locale;

        for my $lang ( sort keys %locales ) {
            my @locale_tags = sort keys %{ $locales{$lang} };
            if ( scalar @locale_tags == 1 ) {
                push @lang_tags, $lang;
            }
            push @lang_tags, @locale_tags;
        }
    };
    if ( $@ ) {
        handle_exception( $@ );
    }

    my $result = {
        languages => \@lang_tags
    };

    return $result;
}

# Deprecated
$json_schemas{get_language_tags} = $json_schemas{conf_languages};
sub get_language_tags {
    my $result = conf_languages( @_ );
    return $result->{languages};
}

$json_schemas{lookup_address_records} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'hostname' ],
    properties => {
        hostname => $zm_validator->domain_name
    }
};
sub lookup_address_records {
    my ( $self, $params ) = @_;
    my @addresses;

    eval {
        my $ns_name  = $params->{hostname};

        @addresses = map { {$ns_name => $_->short} } $recursor->get_addresses_for($ns_name);
        @addresses = { $ns_name => '0.0.0.0' } if not @addresses;

    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        address_records => \@addresses
    };

    return $result;
}

# Deprecated
$json_schemas{get_host_by_name} = $json_schemas{lookup_address_records};
sub get_host_by_name {
    my $result = lookup_address_records( @_ );
    return $result->{address_records};
}

$json_schemas{lookup_delegation_data} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'domain' ],
    properties => {
        domain => $zm_validator->domain_name,
        language => $zm_validator->language_tag,
    }
};
sub lookup_delegation_data {
    my ( $self, $params ) = @_;

    my $result = eval {
        my %result;
        my $domain = $params->{domain};

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
    };
    if ($@) {
        handle_exception( $@ );
    }
    elsif ($result) {
        return $result;
    }
}

# Deprecated
$json_schemas{get_data_from_parent_zone} = $json_schemas{lookup_delegation_data};
sub get_data_from_parent_zone {
    return lookup_delegation_data( @_ );
}

$json_schemas{job_create} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'domain' ],
    properties => {
        domain => $zm_validator->domain_name,
        ipv4 => joi->boolean->compile,
        ipv6 => joi->boolean->compile,
        nameservers => {
            type => 'array',
            items => $zm_validator->nameserver
        },
        ds_info => {
            type => 'array',
            items => $zm_validator->ds_info
        },
        profile => $zm_validator->profile_name,
        client_id => $zm_validator->client_id->compile,
        client_version => $zm_validator->client_version->compile,
        config => joi->string->compile,
        priority => $zm_validator->priority->compile,
        queue => $zm_validator->queue->compile,
        language => $zm_validator->language_tag,
    }
};
sub job_create {
    my ( $self, $params ) = @_;

    my $job_id = 0;
    eval {
        $params->{domain} =~ s/^\.// unless ( !$params->{domain} || $params->{domain} eq '.' );

        die "No domain in parameters\n" unless ( defined $params->{domain} && length($params->{domain}) );

        $params->{profile}  //= "default";
        $params->{priority} //= 10;
        $params->{queue}    //= 0;

        my $profile = $self->{_profiles}{ $params->{profile} };
        $params->{ipv4} //= $profile->get( "net.ipv4" );
        $params->{ipv6} //= $profile->get( "net.ipv6" );

        $job_id = $self->{db}->create_new_test( $params->{domain}, $params, $self->{config}->ZONEMASTER_age_reuse_previous_test );
    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        job_id => $job_id
    };

    return $result;
}

# Deprecated
$json_schemas{start_domain_test} = $json_schemas{job_create};
sub start_domain_test {
    my $result = job_create( @_ );
    return $result->{job_id};
}

$json_schemas{job_status} = joi->object->strict->props(
    job_id => $zm_validator->test_id->required
);
sub job_status {
    my ( $self, $params ) = @_;

    my $progress = 0;
    eval {
        my $job_id = $params->{job_id};
        $progress = $self->{db}->test_progress( $job_id );
    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        progress => $progress
    };

    return $result;
}

# Deprecated
$json_schemas{test_progress} = joi->object->strict->props(
    test_id => $zm_validator->test_id->required
);
sub test_progress {
    my ( $self, $params ) = @_;
    $params->{job_id} = $params->{test_id};
    my $result = $self->job_status( $params );
    return $result->{progress};
}

$json_schemas{job_params} = joi->object->strict->props(
    job_id => $zm_validator->test_id->required
);
sub job_params {
    my ( $self, $params ) = @_;

    my $result;
    eval {
        my $job_id = $params->{job_id};

        $result = $self->{db}->get_test_params( $job_id );
    };
    if ($@) {
        handle_exception( $@ );
    }

    return $result;
}

# Deprecated
$json_schemas{get_test_params} = joi->object->strict->props(
    test_id => $zm_validator->test_id->required
);
sub get_test_params {
    my ( $self, $params ) = @_;
    $params->{job_id} = $params->{test_id};
    return $self->job_params( $params );
}

$json_schemas{job_results} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'job_id', 'language' ],
    properties => {
        job_id => $zm_validator->test_id->required->compile,
        language => $zm_validator->language_tag,
    }
};
sub job_results {
    my ( $self, $params ) = @_;

    my $result;
    eval{

        my $locale = $self->_get_locale( $params );

        my $translator;
        $translator = Zonemaster::Backend::Translator->new;

        my $previous_locale = $translator->locale;
        if ( !$translator->locale( $locale ) ) {
            die "Failed to set locale: $locale";
        }

        eval { $translator->data } if $translator; # Provoke lazy loading of translation data

        my @zm_results;
        my %testcases;

        my $test_info = $self->{db}->test_results( $params->{job_id} );
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
            $res->{message} = $translator->translate_tag( $test_res ) . "\n";
            $res->{message} =~ s/,/, /isg;
            $res->{message} =~ s/;/; /isg;
            $res->{level} = $test_res->{level};
            $res->{testcase} = $test_res->{testcase} // 'UNSPECIFIED';
            $testcases{$res->{testcase}} = $translator->test_case_description($res->{testcase});

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
        $result->{testcase_descriptions} = \%testcases;
        $result->{results} = \@zm_results;

        $translator->locale( $previous_locale );

        $result = $test_info;
        $result->{results} = \@zm_results;
    };
    if ($@) {
        handle_exception( $@ );
    }

    return $result;
}

# Deprecated
$json_schemas{get_test_results} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'id', 'language' ],
    properties => {
        id => $zm_validator->test_id->required->compile,
        language => $zm_validator->language_tag,
    }
};
sub get_test_results {
    my ( $self, $params ) = @_;
    $params->{job_id} = $params->{id};
    return $self->job_results( $params );
}

$json_schemas{domain_history} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'frontend_params' ],
    properties => {
        offset => joi->integer->min(0)->compile,
        limit => joi->integer->min(0)->compile,
        filter => joi->string->regex('^(?:all|delegated|undelegated)$')->compile,
        frontend_params => {
            type => 'object',
            additionalProperties => 0,
            required => [ 'domain' ],
            properties => {
                domain => $zm_validator->domain_name
            }
        }
    }
};
sub domain_history {
    my ( $self, $params ) = @_;

    my @history;

    eval {
        $params->{offset} //= 0;
        $params->{limit} //= 200;
        $params->{filter} //= "all";

        my $results = $self->{db}->get_test_history( $params );
        @history = map { { %$_, undelegated => $_->{undelegated} ? JSON::PP::true : JSON::PP::false } } @$results;
    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        history => \@history
    };

    return $result;
}

# Deprecated
$json_schemas{get_test_history} = $json_schemas{domain_history};
sub get_test_history {
    my $result = domain_history( @_ );
    foreach my $res ( @{ $result->{history} } ) {
        $res->{id} = delete $res->{job_id};
    }
    return $result->{history};
}

$json_schemas{user_create} = joi->object->strict->props(
    username => $zm_validator->username->required,
    api_key => $zm_validator->api_key->required,
);
sub user_create {
    my ( $self, $params, undef, $remote_ip ) = @_;

    my $success = 0;

    eval {
        my $allow = 0;
        if ( defined $remote_ip ) {
            $allow = 1 if ( $remote_ip eq '::1' || $remote_ip eq '127.0.0.1' || $remote_ip eq '::ffff:127.0.0.1' );
        }
        else {
            $allow = 1;
        }

        if ( $allow ) {
            $success = 1 if ( $self->{db}->add_api_user( $params->{username}, $params->{api_key} ) eq '1' );
        }
        else {
            die Zonemaster::Backend::Error::PermissionDenied->new(
                message => 'Call to "add_api_user" method not permitted from a remote IP',
                data => { remote_ip => $remote_ip }
            );
        }
    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        success => $success
    };

    return $result;
}

# Deprecated
$json_schemas{add_api_user} = $json_schemas{user_create};
sub add_api_user {
    my $result = user_create( @_ );
    return $result->{success};
}

$json_schemas{batch_create} = {
    type => 'object',
    additionalProperties => 0,
    required => [ 'username', 'api_key', 'domains' ],
    properties => {
        username => $zm_validator->username->required->compile,
        api_key => $zm_validator->api_key->required->compile,
        domains => {
            type => "array",
            additionalItems => 0,
            items => $zm_validator->domain_name,
            minItems => 1
        },
        job_params => {
            type => 'object',
            additionalProperties => 0,
            properties => {
                ipv4 => joi->boolean->compile,
                ipv6 => joi->boolean->compile,
                nameservers => {
                    type => 'array',
                    items => $zm_validator->nameserver
                },
                ds_info => {
                    type => 'array',
                    items => $zm_validator->ds_info
                },
                profile => $zm_validator->profile_name,
                client_id => $zm_validator->client_id->compile,
                client_version => $zm_validator->client_version->compile,
                config => joi->string->compile,
                priority => $zm_validator->priority->compile,
                queue => $zm_validator->queue->compile,
            }
        }
    }
};
sub batch_create {
    my ( $self, $params ) = @_;

    my $batch_id;
    eval {
        $params->{job_params}{profile}  //= "default";
        $params->{job_params}{priority} //= 5;
        $params->{job_params}{queue}    //= 0;

        my $profile = $self->{_profiles}{ $params->{job_params}{profile} };
        $params->{job_params}{ipv4} //= $profile->get( "net.ipv4" );
        $params->{job_params}{ipv6} //= $profile->get( "net.ipv6" );

        $batch_id = $self->{db}->add_batch_job( $params );
    };
    if ($@) {
        handle_exception( $@ );
    }

    my $result = {
        batch_id => $batch_id
    };

    return $result;
}

# Deprecated
$json_schemas{add_batch_job} = $json_schemas{batch_create};
$json_schemas{add_batch_job}{properties}{test_params} = $json_schemas{add_batch_job}{properties}{job_params};
sub add_batch_job {
    my ( $self, $params ) = @_;
    $params->{job_params} = $params->{test_params} // {};
    my $result = $self->batch_create( $params );
    return $result->{batch_id};
}

$json_schemas{batch_status} = joi->object->strict->props(
    batch_id => $zm_validator->batch_id->required
);
sub batch_status {
    my ( $self, $params ) = @_;

    my $result;
    eval {
        my $batch_id = $params->{batch_id};

        $result = $self->{db}->get_batch_job_result($batch_id);
    };
    if ($@) {
        handle_exception( $@ );
    }

    return $result;
}

# Deprecated
$json_schemas{get_batch_job_result} = $json_schemas{batch_status};
sub get_batch_job_result {
    my $results = batch_status( @_ );
    if ( exists $results->{finished_job_ids} ) {
        $results->{finished_test_ids} = delete $results->{finished_job_ids};
    }
    return $results;
}

sub _get_locale {
    my ( $self, $params ) = @_;
    my @error;

    my $language = $params->{language};
    my $locale;

    if ( !defined $language ) {
        return undef;
    }

    if ( length $language == 2 ) {
        my %locales = $self->{config}->LANGUAGE_locale;
        ( $locale ) = keys %{ $locales{$language} };
    }
    else {
        $locale = $language;
    }

    if (defined $locale) {
        $locale .= '.UTF-8';
    }

    return $locale;
}

sub _set_error_message_locale {
    my ( $self, $params ) = @_;

    my @error_response = ();
    my $locale = $self->_get_locale( $params );

    if (not defined $locale or $locale eq "") {
        # Don't translate message if locale is not defined
        $locale = "C";
    }

    # Use POSIX implementation instead of Locale::Messages wrapper
    setlocale( LC_ALL, $locale );
    return @error_response;
}

my $rpc_request = joi->object->props(
    jsonrpc => joi->string->required,
    method => $zm_validator->jsonrpc_method()->required);
sub jsonrpc_validate {
    my ( $self, $jsonrpc_request) = @_;

    my @error_rpc = $rpc_request->validate($jsonrpc_request);
    if (!exists $jsonrpc_request->{id} || @error_rpc) {
        $self->_set_error_message_locale;
        return {
            jsonrpc => '2.0',
            id => undef,
            error => {
                code => '-32600',
                message => 'The JSON sent is not a valid request object.',
                data => "@error_rpc"
            }
        }
    }

    my $method_schema = $json_schemas{$jsonrpc_request->{method}};
    # the JSON schema for the method has a 'required' key
    if ( exists $method_schema->{required} ) {
        if ( not exists $jsonrpc_request->{params} ) {
            return {
                jsonrpc => '2.0',
                id => $jsonrpc_request->{id},
                error => {
                    code => '-32602',
                    message => "Missing 'params' object",
                }
            };
        }
        my @error_response = $self->validate_params($method_schema, $jsonrpc_request->{params});

        if ( scalar @error_response ) {
            return {
                jsonrpc => '2.0',
                id => $jsonrpc_request->{id},
                error => {
                    code => '-32602',
                    message => decode_utf8(__ 'Invalid method parameter(s).'),
                    data => \@error_response
                }
            };
        }
    }

    return '';
}

sub validate_params {
    my ( $self, $method_schema, $params ) = @_;
    my @error_response = ();

    push @error_response, $self->_set_error_message_locale( $params );

    if (blessed $method_schema) {
        $method_schema = $method_schema->compile;
    }
    my $jv = JSON::Validator::Schema::Draft7->new->coerce('booleans,numbers,strings')->data($method_schema);
    $jv->formats(Zonemaster::Backend::Validator::formats( $self->{config} ));
    my @json_validation_error = $jv->validate( $params );

    # Customize error message from json validation
    foreach my $err ( @json_validation_error ) {
        my $message = $err->message;
        my @details = @{$err->details};

        # Handle 'required' errors globally so it does not get overwritten
        if ($details[1] eq 'required') {
            $message = N__ 'Missing property';
        } else {
            my @path = split '/', $err->path, -1;
            shift @path; # first item is an empty string
            my $found = 1;
            my $data = Mojo::JSON::Pointer->new($method_schema);

            foreach my $p (@path) {
                if ( $data->contains("/properties/$p") ) {
                    $data = $data->get("/properties/$p")
                } elsif ( $p =~ /^\d+$/ and $data->contains("/items") ) {
                    $data = $data->get("/items")
                } else {
                    $found = 0;
                    last;
                }
                $data = Mojo::JSON::Pointer->new($data);
            }

            if ($found and exists $data->data->{'x-error-message'}) {
                $message = $data->data->{'x-error-message'};
            }
        }

        push @error_response, { path => $err->path, message => $message };

    }

    # Translate messages
    @error_response = map { { %$_,  ( message => decode_utf8 __ $_->{message} ) } } @error_response;

    return @error_response;
}

1;

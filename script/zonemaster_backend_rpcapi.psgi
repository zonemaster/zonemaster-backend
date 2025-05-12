#!/usr/bin/env perl
use strict;
use warnings;

our $VERSION = '1.1.0';

use 5.14.2;

use English qw( $PID );
use JSON::PP;
use JSON::RPC::Dispatch;
use Log::Any qw( $log );
use Log::Any::Adapter;
use POSIX;
use Plack::Builder;
use Plack::Response;
use Router::Simple::Declare;
use Try::Tiny;

BEGIN {
    $ENV{PERL_JSON_BACKEND} = 'JSON::PP';
    undef $ENV{LANGUAGE};
};

use Zonemaster::Backend::RPCAPI;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::Metrics;

local $| = 1;

Log::Any::Adapter->set(
    '+Zonemaster::Backend::Log',
    log_level => $ENV{ZM_BACKEND_RPCAPI_LOGLEVEL},
    json => $ENV{ZM_BACKEND_RPCAPI_LOGJSON},
    stderr => 1
);

$SIG{__WARN__} = sub {
    $log->warning(map s/^\s+|\s+$//gr, map s/\n/ /gr, @_);
};

my $config = Zonemaster::Backend::Config->load_config();

Zonemaster::Backend::Metrics->setup($config->METRICS_statsd_host, $config->METRICS_statsd_port);
Zonemaster::Engine::init_engine();

builder {
    enable sub {
        my $app = shift;

        # Make sure we can connect to the database
        $config->new_DB();

        return $app;
    };
};

my $handler = Zonemaster::Backend::RPCAPI->new( { config => $config } );

my $router = router {
############## FRONTEND ####################
    connect "version_info" => {
        handler => $handler,
        action => "version_info"
    };

    # Experimental
    connect "system_versions" => {
        handler => $handler,
        action => "system_versions"
    };

    connect "profile_names" => {
        handler => $handler,
        action => "profile_names"
    };

    # Experimental
    connect "conf_profiles" => {
        handler => $handler,
        action => "conf_profiles"
    };

    connect "get_language_tags" => {
        handler => $handler,
        action => "get_language_tags"
    };

    # Experimental
    connect "conf_languages" => {
        handler => $handler,
        action => "conf_languages"
    };

    connect "get_host_by_name" => {
        handler => $handler,
        action => "get_host_by_name"
    };

    # Experimental
    connect "lookup_address_records" => {
        handler => $handler,
        action => "lookup_address_records"
    };

    connect "get_data_from_parent_zone" => {
        handler => $handler,
        action => "get_data_from_parent_zone"
    };

    # Experimental
    connect "lookup_delegation_data" => {
        handler => $handler,
        action => "lookup_delegation_data"
    };

    connect "start_domain_test" => {
        handler => $handler,
        action => "start_domain_test"
    };

    # Experimental
    connect "job_create" => {
        handler => $handler,
        action => "job_create"
    };

    connect "test_progress" => {
        handler => $handler,
        action => "test_progress"
    };

    # Experimental
    connect "job_status" => {
        handler => $handler,
        action => "job_status"
    };

    connect "get_test_params" => {
        handler => $handler,
        action => "get_test_params"
    };

    # Experimental
    connect "job_params" => {
        handler => $handler,
        action => "job_params"
    };

    connect "get_test_results" => {
        handler => $handler,
        action => "get_test_results"
    };

    # Experimental
    connect "job_results" => {
        handler => $handler,
        action => "job_results"
    };

    connect "get_test_history" => {
        handler => $handler,
        action => "get_test_history"
    };

    # Experimental
    connect "domain_history" => {
        handler => $handler,
        action => "domain_history"
    };

    # Deprecated to be removed v2025.2
    connect "get_batch_job_result" => {
        handler => $handler,
        action => "get_batch_job_result"
    };

    connect "batch_status" => {
        handler => $handler,
        action => "batch_status"
    };
};

if ( $config->RPCAPI_enable_user_create or $config->RPCAPI_enable_add_api_user ) {
    $log->info('Enabling add_api_user method');
    $router->connect("add_api_user", {
        handler => $handler,
        action => "add_api_user"
    });
    $router->connect("user_create", {
        handler => $handler,
        action => "user_create"
    });
}

if ( $config->RPCAPI_enable_batch_create or $config->RPCAPI_enable_add_batch_job ) {
    $log->info('Enabling add_batch_job method');
    $router->connect("add_batch_job", {
        handler => $handler,
        action => "add_batch_job"
    });
    $router->connect("batch_create", {
        handler => $handler,
        action => "batch_create"
    });
}

my $dispatch = JSON::RPC::Dispatch->new(
    router => $router,
);

my $rpcapi_app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $res = {};
    my $content = {};
    my $json_error = '';
    try {
        my $json = $req->content;
        $content = decode_json($json);
    } catch {
        $json_error = (split /at \//, $_)[0];
    };

    if ($json_error eq '') {
        my $errors = $handler->jsonrpc_validate($content);
        if ($errors ne '') {
          $res = Plack::Response->new(200);
          $res->content_type('application/json');
          $res->body( encode_json($errors) );
          $res->finalize;
        } else {
            local $log->context->{rpc_method} = $content->{method};
            $res = $dispatch->handle_psgi($env, $env->{REMOTE_ADDR});
            my $status = Zonemaster::Backend::Metrics->code_to_status(decode_json(@{@$res[2]}[0])->{error}->{code});
            Zonemaster::Backend::Metrics::increment("zonemaster.rpcapi.requests.$content->{method}.$status");
            $res;
        }
    } else {
        $res = Plack::Response->new(200);
        $res->content_type('application/json');
        $res->body( encode_json({
                    jsonrpc => '2.0',
                    id => undef,
                    error => {
                        code => '-32700',
                        message => 'Invalid JSON was received by the server.',
                        data => "$json_error"
                    }}) );
        $res->finalize;

    }
};

builder {
    enable "Plack::Middleware::ReverseProxy";
    mount "/" => $rpcapi_app;
};

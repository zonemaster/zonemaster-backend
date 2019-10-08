#!/usr/bin/env perl
use strict;
use warnings;

our $VERSION = '1.1.0';

use 5.14.2;

use JSON::RPC::Dispatch;
use Router::Simple::Declare;
use JSON::PP;
use POSIX;
use Try::Tiny;

use Plack::Builder;
use Plack::Response;

BEGIN { $ENV{PERL_JSON_BACKEND} = 'JSON::PP' };

use Zonemaster::Backend::RPCAPI;
use Zonemaster::Backend::Config;

local $| = 1;

builder {
    enable 'Debug';
    enable sub {
        my $app = shift;

        # Make sure we can connect to the database
        Zonemaster::Backend::Config->load_config()->new_DB();

        return $app;
    };
};

my $router = router {
############## FRONTEND ####################
	connect "version_info" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "version_info"
	};

	connect "profile_names" => {
        handler => "+Zonemaster::Backend::RPCAPI",
        action => "profile_names"
  };
  
  connect "get_host_by_name" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_host_by_name"
	};

	connect "get_data_from_parent_zone" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_data_from_parent_zone"
	};

	connect "start_domain_test" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "start_domain_test"
	};
	
	connect "test_progress" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "test_progress"
	};
	
	connect "get_test_params" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_test_params"
	};

	connect "get_test_results" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_test_results"
	};

	connect "get_test_history" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_test_history"
	};

############ BATCH MODE ####################

	connect "add_api_user" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "add_api_user"
	};

	connect "add_batch_job" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "add_batch_job"
	};

	connect "get_batch_job_result" => {
		handler => "+Zonemaster::Backend::RPCAPI",
		action => "get_batch_job_result"
	};
};

my $dispatch = JSON::RPC::Dispatch->new(
	router => $router,
);

sub {
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
        my $errors = Zonemaster::Backend::RPCAPI->jsonrpc_validate($content);
        if ($errors ne '') {
          $res = Plack::Response->new(200);
          $res->content_type('application/json');
          $res->body( encode_json($errors) );
          $res->finalize;
        } else {
            $dispatch->handle_psgi($env, $env->{REMOTE_HOST} );
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

use strict;
use warnings;
use 5.14.2;
use utf8;

use Test::More tests => 4;
use Test::NoWarnings;

use File::Temp qw[tempdir];
use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;
use JSON::Validator::Joi "joi";
use JSON::PP;


my $tempdir = tempdir( CLEANUP => 1 );

my $config = Zonemaster::Backend::Config->parse( <<EOF );
[DB]
engine = SQLite

[SQLITE]
database_file = $tempdir/zonemaster.sqlite
EOF

my $rpcapi = Zonemaster::Backend::RPCAPI->new(
    {
        dbtype => $config->DB_engine,
        config => $config,
    }
);

sub test_validation {
    my ( $method, $test_cases ) = @_;

    subtest "Method $method" => sub {
        for my $test_case (@$test_cases) {
            subtest 'Test case: ' . $test_case->{name} => sub {
                my @res = $rpcapi->validate_params( $method,  $test_case->{input});
                is_deeply(\@res, $test_case->{output}, 'Matched validation output' ) or diag( encode_json \@res);
            };
        }
    };
}

subtest 'Test JSON schema' => sub {
    local $Zonemaster::Backend::RPCAPI::json_schemas{test_joi} = joi->new->object->strict->props(
        hostname => joi->new->string->max(10)->required
    );

    local $Zonemaster::Backend::RPCAPI::json_schemas{test_raw_schema} = {
        type => 'object',
        additionalProperties => 0,
        required => [ 'hostname' ],
        properties => {
            hostname => {
                type => 'string',
                maxLength => 10
            }
        }
    };

    my $test_cases = [
        {
            name => 'Empty request',
            input => {},
            output => [{
                message => 'Missing property',
                path => '/hostname'
            }]
        },
        {
            name => 'Correct request',
            input => {
                hostname => 'example'
            },
            output => []
        },
        {
            name => 'Bad request',
            input => {
                hostname => 'example.toolong'
            },
            output => [{
                message => 'String is too long: 15/10.',
                path => '/hostname'
            }]
        }
    ];

    test_validation 'test_joi', $test_cases;
    test_validation 'test_raw_schema', $test_cases;
};

subtest 'Test custom error message' => sub {
    local $Zonemaster::Backend::RPCAPI::json_schemas{test_custom_error} = {
        type => 'object',
        additionalProperties => 0,
        required => [ 'hostname' ],
        additionalProperties => 0,
        properties => {
            hostname => {
                type => 'string',
                'x-error-message' => 'Bad hostname, should be a string less than 10 characters long',
                maxLength => 10
            },
            nameservers => {
                type => 'array',
                items => {
                    type => 'object',
                    required => [ 'ip' ],
                    additionalProperties => 0,
                    properties => {
                        ip => {
                            type => 'string',
                            'x-error-message' => 'Bad IP address',
                            pattern => '^[a-f0-9\.:]+$'
                        }
                    }
                }
            }
        }
    };

    my $test_cases = [
        {
            name => 'Bad input',
            input => {
                hostname => 'This is a bad input',
                nameservers => [
                    { ip => 'Very bad indeed'},
                    { ip => '10.10.10.10' },
                    { ip => 'But not the previous property' }
                ]
            },
            output => [
                {
                    path => '/hostname',
                    message => 'Bad hostname, should be a string less than 10 characters long',
                },
                {
                    path => '/nameservers/0/ip',
                    message => 'Bad IP address',
                },
                {
                    path => '/nameservers/2/ip',
                    message => 'Bad IP address',
                }
            ]
        }
    ];

    test_validation 'test_custom_error', $test_cases;
};

subtest 'Test extra validators' => sub {
    local $Zonemaster::Backend::RPCAPI::extra_validators{test_extra_validator} = sub {
        my ($self, $input) = @_;
        my @errors;
        if ( $input->{answer} != 42 ) {
            push @errors, { path => '/answer', message => 'Not the expected answer' };
        }

        return @errors;
    };

    local $Zonemaster::Backend::RPCAPI::json_schemas{test_extra_validator} = {
        type => 'object',
        properties => {
            answer => {
                type => 'number',
            }
        }
    };

    my $test_cases = [
        {
            name => 'Input ok',
            input => {
                answer => 42,
            },
            output => []
        },
        {
            name => 'Bad input',
            input => {
                answer => 0,
            },
            output => [{
                path => '/answer',
                message => 'Not the expected answer'
            }]
        }
    ];

    test_validation 'test_extra_validator', $test_cases;
};

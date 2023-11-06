use strict;
use warnings;
use 5.14.2;
use utf8;

use Test::More tests => 4;
use Test::NoWarnings;

use Cwd;
use File::Temp qw[tempdir];
use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;
use JSON::Validator::Joi "joi";
use JSON::PP;

my $tempdir = tempdir( CLEANUP => 1 );
my $cwd = cwd();

my $config = Zonemaster::Backend::Config->parse( <<EOF );
[DB]
engine = SQLite

[SQLITE]
database_file = $tempdir/zonemaster.sqlite

[PUBLIC PROFILES]
test = $cwd/t/test_profile.json
EOF

my $rpcapi = Zonemaster::Backend::RPCAPI->new(
    {
        dbtype => $config->DB_engine,
        config => $config,
    }
);

sub test_validation {
    my ( $method_name, $method_schema, $test_cases ) = @_;

    subtest "Method $method_name" => sub {
        for my $test_case (@$test_cases) {
            subtest 'Test case: ' . $test_case->{name} => sub {
                my @res = $rpcapi->validate_params( $method_schema, $test_case->{input});
                is_deeply(\@res, $test_case->{output}, 'Matched validation output' ) or diag( encode_json \@res);
            };
        }
    };
}

subtest 'Test JSON schema' => sub {
    my $test_joi_schema = joi->new->object->strict->props(
        hostname => joi->new->string->max(10)->required
    );

    my $test_raw_schema = {
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

    test_validation 'test_joi', $test_joi_schema, $test_cases;
    test_validation 'test_raw', $test_raw_schema, $test_cases;
};

subtest 'Test custom error message' => sub {
    my $test_custom_error_schema = {
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

    test_validation 'test_custom_error', $test_custom_error_schema, $test_cases;
};

subtest 'Test custom formats' => sub {
    my $test_extra_validator_schema = {
        type => 'object',
        properties => {
            my_ip => {
                type => 'string',
                format => 'ip',
            },
            my_lang => {
                type => 'string',
                format => 'language_tag',
            },
            my_domain => {
                type => 'string',
                format => 'domain',
            },
            my_profile => {
                type => 'string',
                format => 'profile',
            },
        }
    };

    my $test_cases = [
        {
            name => 'Input ok',
            input => {
                my_ip => '192.0.2.1',
                my_lang => 'en',
                my_domain => 'zonemaster.net',
                my_profile => 'test',
            },
            output => []
        },
        {
            name => 'Bad ip',
            input => {
                my_ip => 'abc',
            },
            output => [{
                path => '/my_ip',
                message => 'Invalid IP address'
            }]
        },
        {
            name => 'Bad language format',
            input => {
                my_lang => 'abc',
            },
            output => [{
                path => '/my_lang',
                message => 'Invalid language tag format'
            }]
        },
        {
            name => 'Bad domain',
            input => {
                my_domain => 'not a domain',
            },
            output => [{
                path => '/my_domain',
                message => 'Domain name has an ASCII label ("not a domain") with a character not permitted.'
            }]
        },
        {
            name => 'Bad profile',
            input => {
                my_profile => 'other_profile',
            },
            output => [{
                path => '/my_profile',
                message => 'Unknown profile'
            }]
        },
    ];

    test_validation 'test_extra_validator', $test_extra_validator_schema, $test_cases;
};

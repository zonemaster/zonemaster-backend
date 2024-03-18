use strict;
use warnings;
use 5.14.2;
use utf8;

use Test::More tests => 30;
use Test::NoWarnings;

use Cwd;
use File::Temp qw[tempdir];
use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;
use JSON::Validator::Joi "joi";
use JSON::PP;

###
### Setup
###

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

###
### JSONRPC request object construction helper
###

sub jsonrpc
{
    my ($method, $params, $force_undef) = @_;
    my $object = {
        jsonrpc => '2.0',
        id => 'testing',
        method => $method
    };
    if (defined $params or $force_undef) {
        $object->{params} = $params;
    }

    return $object;
}

###
### JSONRPC error response construction helpers
###

sub jsonrpc_error
{
    my ($message, $code, $data, $id) = @_;
    my $object = {
        jsonrpc => '2.0',
        id => $id,
        error => {
            message => $message,
            code => $code
        }
    };
    $object->{error}{data} = $data if defined $data;
    return $object;
}

sub error_bad_jsonrpc
{
    my ($data) = @_;

    jsonrpc_error('The JSON sent is not a valid request object.', '-32600', $data, undef);
}

sub error_missing_params
{
    jsonrpc_error("Missing 'params' object", '-32602', undef, 'testing');
}

sub error_bad_params
{
    my ($messages) = @_;

    my @data;

    while (@$messages) {
        my $path = shift @$messages;
        my $message = shift @$messages;
        push @data, { path => $path, message => $message };
    }

    jsonrpc_error('Invalid method parameter(s).', '-32602', \@data, 'testing');
}

sub no_error
{
    return '';
}

###
### Test wrapper functions
###

sub test_validation
{
    my ($input, $output, $message) = @_;

    my $res = $rpcapi->jsonrpc_validate($input);
    is_deeply($res, $output, $message) or diag(encode_json($res));
}


###
### The tests themselves
###

test_validation undef,
    error_bad_jsonrpc('/: Expected object - got null.'),
    "Sending undef is an error";

test_validation JSON::PP::false,
    error_bad_jsonrpc('/: Expected object - got boolean.'),
    "Sending a boolean is an error";

test_validation -1,
    error_bad_jsonrpc('/: Expected object - got number.'),
    "Sending a number is an error";

test_validation "hello",
    error_bad_jsonrpc('/: Expected object - got string.'),
    "Sending a string is an error";

test_validation [qw(a b c)],
    error_bad_jsonrpc('/: Expected object - got array.'),
    "Sending an array is an error";

test_validation {},
    error_bad_jsonrpc('/jsonrpc: Missing property. /method: Missing property.'),
    "Sending an empty object is an error";

test_validation { jsonrpc => '2.0' },
    error_bad_jsonrpc('/method: Missing property.'),
    "Sending an incomplete object is an error";

test_validation { jsonrpc => '2.0', method => 'system_versions' },
    error_bad_jsonrpc(''),
    "Sending an object with no ID is an error";

test_validation { jsonrpc => '2.0', method => 'system_versions', id => JSON::PP::false },
    error_bad_jsonrpc('/id: Expected null/number/string - got boolean.'),
    "Sending an object whose ID is a boolean is an error";

test_validation { jsonrpc => '2.0', method => 'system_versions', id => [qw(a b c)] },
    error_bad_jsonrpc('/id: Expected null/number/string - got array.'),
    "Sending an object whose ID is an array is an error";

test_validation { jsonrpc => '2.0', method => 'system_versions', id => { a => 1 } },
    error_bad_jsonrpc('/id: Expected null/number/string - got object.'),
    "Sending an object whose ID is an object is an error";

test_validation jsonrpc("job_status"),
    error_missing_params(),
    "Calling job_status without parameters is an error";

test_validation jsonrpc("job_status", undef, 1),
    error_bad_params(["/" => "Expected object - got null."]),
    "Passing null as parameter to job_status is an error";

test_validation jsonrpc("job_status", JSON::PP::false),
    error_bad_params(["/" => "Expected object - got boolean."]),
    "Passing boolean as parameter to job_status is an error";

test_validation jsonrpc("job_status", 1),
    error_bad_params(["/" => "Expected object - got number."]),
    "Passing number as parameter to job_status is an error";

test_validation jsonrpc("job_status", "hello"),
    error_bad_params(["/" => "Expected object - got string."]),
    "Passing string as parameter to job_status is an error";

test_validation jsonrpc("job_status", [qw(a b c)]),
    error_bad_params(["/" => "Expected object - got array."]),
    "Passing array as parameter to job_status is an error";

test_validation jsonrpc("job_status", {}),
    error_bad_params(["/test_id" => "Missing property"]),
    "Passing empty object as parameter to job_status is an error";

test_validation jsonrpc("job_status", { test_id => 'this_will_definitely_never_ever_exist' }),
    error_bad_params(["/test_id" => 'String does not match (?^u:^[0-9a-f]{16}$).']),
    "Calling job_status with a bad test_id is an error";

test_validation jsonrpc("job_status", { test_id => '0123456789abcdef', data => "something" }),
    error_bad_params(["/" => "Properties not allowed: data."]),
    "Calling job_status with unknown parameters is an error";

test_validation jsonrpc("job_status", { test_id => '0123456789abcdef' }),
    no_error,
    "Calling job_status with a good test_id succeeds";

test_validation jsonrpc("system_versions"),
    no_error,
    "Calling system_versions with no parameters is OK";

test_validation jsonrpc("system_versions", undef, 1),
    error_bad_params(["/" => "Expected object - got null."]),
    "Passing null as parameter to system_versions is an error";

test_validation jsonrpc("system_versions", JSON::PP::false),
    error_bad_params(["/" => "Expected object - got boolean."]),
    "Passing number as parameter to system_versions is an error";

test_validation jsonrpc("system_versions", -1),
    error_bad_params(["/" => "Expected object - got number."]),
    "Passing number as parameter to system_versions is an error";

test_validation jsonrpc("system_versions", "hello"),
    error_bad_params(["/" => "Expected object - got string."]),
    "Passing string as parameter to system_versions is an error";

test_validation jsonrpc("system_versions", [qw(a b c)]),
    error_bad_params(["/" => "Expected object - got array."]),
    "Passing array as parameter to system_versions is an error";

test_validation jsonrpc("system_versions", { data => "something" }),
    error_bad_params(["/" => "Properties not allowed: data."]),
    "Calling system_versions with unrecognized parameter is an error";

test_validation jsonrpc("system_versions", {}),
    no_error,
    "Calling system_versions with empty object succeeds";

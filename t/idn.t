use strict;
use warnings;
use 5.14.2;

use Cwd;
use Data::Dumper;
use File::Temp qw[tempdir];
use JSON::PP;
use Test::Exception;
use Test::More;    # see done_testing()
use utf8;

use Zonemaster::Engine;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::TestAgent;

my $db_backend = Zonemaster::Backend::Config->check_db( $ENV{TARGET} || 'SQLite' );
note "database: $db_backend";

my $tempdir = tempdir( CLEANUP => 1 );

my $datafile = q{t/idn.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine->preload_cache( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
    diag "not recording";
} else {
    diag "recording";
}

my $cwd = cwd();

my $config = Zonemaster::Backend::Config->parse( <<EOF );
[DB]
engine = $db_backend

[MYSQL]
host     = localhost
user     = travis_zm
password = travis_zonemaster
database = travis_zonemaster

[POSTGRESQL]
host     = localhost
user     = travis_zonemaster
password = travis_zonemaster
database = travis_zonemaster

[SQLITE]
database_file = $tempdir/zonemaster.sqlite

[LANGUAGE]
locale = en_US

[PUBLIC PROFILES]
test_profile=$cwd/t/test_profile.json
EOF

my $dbclass = Zonemaster::Backend::DB->get_db_class( $db_backend );
my $db      = $dbclass->from_config( $config );

# prepare the database
$db->drop_tables();
$db->create_schema();

# Create the agent
my $agent = Zonemaster::Backend::TestAgent->new( { dbtype => "$db_backend", config => $config } );

# define the default properties for the tests
my $params = {
    client_id      => 'Unit Test',
    client_version => '1.0',
    domain         => 'café.example',
    ipv4           => JSON::PP::true,
    ipv6           => JSON::PP::true,
    profile        => 'default',
};

my $test_id;

subtest 'test IDN domain' => sub {
    $test_id = $db->create_new_test( $params->{domain}, $params, 10 );

    my $res = $db->get_test_params( $test_id );
    note Dumper($res);
    is( $res->{domain}, $params->{domain}, 'Retrieve the correct "domain" value' );
};

# run the test
$agent->run( $test_id ); # blocking call

subtest 'test get_test_results' => sub {
    my $res = $db->test_results( $test_id );
    is( $res->{params}->{domain}, $params->{domain}, 'Retrieve the correct domain name' );
};


subtest 'test IDN nameserver' => sub {
    $params->{nameservers} = [ { ns => "anøthær.example" } ];

    $test_id = $db->create_new_test( $params->{domain}, $params, 10 );

    subtest 'get_test_params' => sub {
        my $res = $db->get_test_params( $test_id );
        note Dumper($res);
        is_deeply( $res->{nameservers}, $params->{nameservers}, 'Retrieve the correct "nameservers" value' );
    };

    # run the test
    $agent->run( $test_id ); # blocking call

    subtest 'test_results' => sub {
        my $res = $db->test_results( $test_id );
        is_deeply( $res->{params}->{nameservers}, $params->{nameservers}, 'Retrieve the correct nameservers parameters' );
    };
};

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine->save_cache( $datafile );
}

done_testing();

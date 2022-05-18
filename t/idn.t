use strict;
use warnings;
use 5.14.2;

use Data::Dumper;
use File::Temp qw[tempdir];
use Test::Exception;
use Test::More;    # see done_testing()
use utf8;

my $t_path;
BEGIN {
    use File::Spec::Functions qw( rel2abs );
    use File::Basename qw( dirname );
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;
use TestUtil qw( TestAgent );

use Zonemaster::Backend::Config;

my $db_backend = TestUtil::db_backend();

my $datafile = "$t_path/idn.data";
TestUtil::restore_datafile( $datafile );

my $tempdir = tempdir( CLEANUP => 1 );
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
test_profile=$t_path/test_profile.json
EOF

my $db = TestUtil::init_db( $config );
my $agent = TestUtil::create_testagent( $config );

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

TestUtil::save_datafile( $datafile );

done_testing();

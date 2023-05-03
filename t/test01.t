use strict;
use warnings;
use 5.14.2;

my $t_path;
BEGIN {
    use File::Spec::Functions qw( rel2abs );
    use File::Basename qw( dirname );
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;
use TestUtil qw( RPCAPI TestAgent );

use Data::Dumper;
use File::Temp qw[tempdir];
use Test::Exception;
use Test::More;    # see done_testing()

use Zonemaster::Engine;
use Zonemaster::Backend::Config;

my $db_backend = TestUtil::db_backend();

my $datafile = "$t_path/test01.data";
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

my $rpcapi = TestUtil::create_rpcapi( $config );

my $dbh = $rpcapi->{db}->dbh;

# Create the agent
my $agent = TestUtil::create_testagent( $config );

# define the default properties for the tests
my $params = {
    client_id      => 'Unit Test',
    client_version => '1.0',
    domain         => 'afnic.fr',
    ipv4           => JSON::PP::true,
    ipv6           => JSON::PP::true,
    profile        => 'test_profile',

    nameservers => [
        { ns => 'ns1.nic.fr' },
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' }
    ],
    ds_info => [
        {
            keytag => 11627,
            algorithm => 8,
            digtype => 2,
            digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448'
        }
    ]
};

my $hash_id;

# This is the first test added to the DB, its 'id' is 1
my $test_id = 1;
subtest 'add a first test' => sub {
    my $res_job_id = $rpcapi->job_create( $params );
    $hash_id = $res_job_id->{job_id};

    ok( $hash_id, "API job_create OK" );
    is( length($hash_id), 16, "Test has a 16 characters length hash ID (hash_id=$hash_id)" );

    my ( $test_id_db, $hash_id_db ) = $dbh->selectrow_array( "SELECT id, hash_id FROM test_results WHERE id=?", undef, $test_id );
    is( $test_id_db, $test_id , 'API job_create -> Test inserted in the DB' );
    is( $hash_id_db, $hash_id , 'Correct hash_id in database' );

    # test job_status API
    my $res_job_status = $rpcapi->job_status( { test_id => $hash_id } );
    is( $res_job_status->{progress}, 0 , 'Test has been created, its progress is 0' );
};

subtest 'get and run test' => sub {
    my ( $hash_id_from_db ) = $rpcapi->{db}->get_test_request();
    is( $hash_id_from_db, $hash_id, 'Get correct test to run' );

    my $res_job_status = $rpcapi->job_status( { test_id => $hash_id } );
    is( $res_job_status->{progress}, 1, 'Test has been picked, its progress is 1' );

    diag "running the agent on test $hash_id";
    $agent->run( $hash_id ); # blocking call

    $res_job_status = $rpcapi->job_status( { test_id => $hash_id } );
    is( $res_job_status->{progress}, 100 , 'Test has finished, its progress is 100' );
};

subtest 'API calls' => sub {

    subtest 'job_results' => sub {
        local $@ = undef;
        my $res = eval { $rpcapi->job_results( { id => $hash_id, language => 'en_US' } ) };
        if ( $@ ) {
            fail 'Crashed while fetching job results: ' . Dumper( $@ );
        }
        ok( ! defined $res->{id}, 'Do not expose primary key' );
        is( $res->{hash_id}, $hash_id, 'Retrieve the correct "hash_id"' );
        ok( defined $res->{params}, 'Value "params" properly defined' );
        ok( ! exists $res->{creation_time}, 'Key "creation_time" should be missing' );
        ok( defined $res->{created_at}, 'Value "created_at" properly defined' );
        ok( defined $res->{results}, 'Value "results" properly defined' );
        if ( @{ $res->{results} } > 1 ) {
            pass 'The test has some results';
        }
        else {
            fail 'The test has some results: ' . Dumper( $res->{results} );
        }
    };

    subtest 'job_params' => sub {
        my $res = $rpcapi->job_params( { test_id => $hash_id } );
        is( $res->{domain}, $params->{domain}, 'Retrieve the correct "domain" value' );
        is( $res->{profile}, $params->{profile}, 'Retrieve the correct "profile" value' );
        is( $res->{client_id}, $params->{client_id}, 'Retrieve the correct "client_id" value' );
        is( $res->{client_version}, $params->{client_version}, 'Retrieve the correct "client_version" value' );
        is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
        is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );
        is_deeply( $res->{nameservers}, $params->{nameservers}, 'Retrieve the correct "nameservers" value' );
        is_deeply( $res->{ds_info}, $params->{ds_info}, 'Retrieve the correct "ds_info" value' );
    };

    subtest 'user_create' => sub {
        my $res;
        eval {
            $res = $rpcapi->user_create( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } );
        };
        is( $res->{success}, 1, 'API user_create success');

        my $user_check_query = q/SELECT * FROM users WHERE username = 'zonemaster_test'/;
        is( scalar( $dbh->selectrow_array( $user_check_query ) ), 1 ,'API user_create user created' );
    };

    subtest 'system_versions' => sub {
        my $res = $rpcapi->system_versions();
        ok( defined( $res->{zonemaster_ldns} ), 'Has a "zonemaster_ldns" key' );
        ok( defined( $res->{zonemaster_engine} ), 'Has a "zonemaster_engine" key' );
        ok( defined( $res->{zonemaster_backend} ), 'Has a "zonemaster_backend" key' );
    };

    subtest 'conf_profiles' => sub {
        my $res = $rpcapi->conf_profiles();
        my $profiles = $res->{profiles};
        is( scalar( @$profiles ), 2, 'There are exactly 2 public profiles' );
        ok( grep( /default/, @$profiles ), 'The profile "default" is defined' );
        ok( grep( /test_profile/, @$profiles ), 'The profile "test_profile" is defined' );
    };

    subtest 'lookup_delegation_data' => sub {
        my $res = $rpcapi->lookup_delegation_data( { domain => "fr" } );
        #diag explain( $res );
        ok( defined( $res->{ns_list} ), 'Has a list of nameservers' );
        ok( defined( $res->{ds_list} ), 'Has a list of DS records' );

        my @ns_list = map { $_->{ns} } @{ $res->{ns_list} };
        ok( grep( /d\.nic\.fr/, @ns_list ), 'Has "d.nic.fr" nameserver' );
        ok( grep( /e\.ext\.nic\.fr/, @ns_list ), 'Has "e.ext.nic.fr" nameserver' );
        ok( grep( /f\.ext\.nic\.fr/, @ns_list ), 'Has "f.ext.nic.fr" nameserver' );
        ok( grep( /g\.ext\.nic\.fr/, @ns_list ), 'Has "g.ext.nic.fr" nameserver' );

        my @ip_list = map { $_->{ip} } @{ $res->{ns_list} };
        ok( grep( /194\.0\.9\.1/, @ip_list ), 'Has "194.0.9.1" ip' ); # d.nic.fr
        ok( grep( /2001:678:c::1/, @ip_list ), 'Has "2001:678:c::1" ip' );
        ok( grep( /194\.0\.36\.1/, @ip_list ), 'Has "194.0.36.1" ip' ); # g.ext.nic.fr
        ok( grep( /2001:678:4c::1/, @ip_list ), 'Has "2001:678:4c::1" ip' );
        ok( grep( /193\.176\.144\.22/, @ip_list ), 'Has "193.176.144.22" ip' ); # e.ext.nic.fr
        ok( grep( /2a00:d78:0:102:193:176:144:22/, @ip_list ), 'Has "2a00:d78:0:102:193:176:144:22" ip' );
        ok( grep( /194\.146\.106\.46/, @ip_list ), 'Has "194.146.106.46" ip' ); # f.ext.nic.fr
        ok( grep( /2001:67c:1010:11::53/, @ip_list ), 'Has "2001:67c:1010:11::53" ip' );

        my $ds_value = {
            'algorithm' => 13,
            'digest' => '1b3386864d30ccc8f4541b985bf2ca320e4f52c57c53353f6d29c9ad58a5671f',
            'digtype' => 2,
            'keytag' => 51508
        };
        is( scalar( @{ $res->{ds_list} } ), 1, 'Has only one DS set' );
        is_deeply( $res->{ds_list}[0], $ds_value, 'Has correct DS values' );
    };

};

# start a second test with IPv6 disabled
$params->{ipv6} = 0;
my $job_res = $rpcapi->job_create( $params );
$hash_id = $job_res->{job_id};
diag "running the agent on test $hash_id";
$agent->run($hash_id);

subtest 'second test has IPv6 disabled' => sub {
    my $res = $rpcapi->job_params( { test_id => $hash_id } );
    is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
    is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );

    $res = $rpcapi->job_results( { id => $hash_id, language => 'en_US' } );
    my @msgs = map { $_->{message} } @{ $res->{results} };
    ok( grep( /IPv6 is disabled/, @msgs ), 'Results contain an "IPv6 is disabled" message' );
};

my $domain_history;
subtest 'domain_history' => sub {
    my $offset = 0;
    my $limit  = 10;
    my $method_params = {
        frontend_params => { domain => $params->{domain} },
        offset => $offset,
        limit => $limit
    };

    my $res_domain_history = $rpcapi->domain_history( $method_params );
    $domain_history = $res_domain_history->{history};
    is( scalar( @$domain_history ), 2, 'Two tests created' );

    foreach my $res (@$domain_history) {
        is( length($res->{id}), 16, 'Test has 16 characters length hash ID' );
        is( $res->{undelegated}, JSON::PP::true, 'Test is undelegated' );
        ok( ! exists $res->{creation_time}, 'Key "creation_time" should be missing' );
        ok( defined $res->{created_at}, 'Value "created_at" properly defined' );
        ok( defined $res->{overall_result}, 'Value "overall_result" properly defined' );
    }

    subtest 'include finished tests only' => sub {
        # start a thirs test with IPv4 disabled
        $params->{ipv6} = 1;
        $params->{ipv4} = 0;

        # create the test, retrieve its id but we don't run it
        $rpcapi->job_create( $params );
        ( $hash_id ) = $rpcapi->{db}->get_test_request();

        my $res_domain_history;
        $res_domain_history = $rpcapi->domain_history( $method_params );
        $domain_history = $res_domain_history->{history};
        is( scalar( @$domain_history ), 2, 'Only 2 tests should be retrieved' );

        # now run the test
        diag "running the agent on test $hash_id";
        $agent->run( $hash_id );

        $res_domain_history = $rpcapi->domain_history( $method_params );
        $domain_history = $res_domain_history->{history};
        is( scalar( @$domain_history ), 3, 'Now 3 tests should be retrieved' );
    }
};

subtest 'mock another client (i.e. reuse a previous test)' => sub {
    $params->{client_id} = 'Another Client';
    $params->{client_version} = '0.1';

    my $res = $rpcapi->job_create( $params );
    my $new_hash_id = $res->{job_id};

    is( $new_hash_id, $hash_id, 'Has the same hash than previous test' );

    subtest 'check test_params values' => sub {
        my $res = $rpcapi->job_params( { test_id => "$hash_id" } );
        # the following values are part of the fingerprint
        is( $res->{domain}, $params->{domain}, 'Retrieve the correct "domain" value' );
        is( $res->{profile}, $params->{profile}, 'Retrieve the correct "profile" value' );
        is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
        is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );
        is_deeply( $res->{nameservers}, $params->{nameservers}, 'Retrieve the correct "nameservers" value' );
        is_deeply( $res->{ds_info}, $params->{ds_info}, 'Retrieve the correct "ds_info" value' );

        # both client_id and client_version are different since an old test has been reused
        isnt( $res->{client_id}, $params->{client_id}, 'The "client_id" value is not the same (which is fine)' );
        isnt( $res->{client_version}, $params->{client_version}, 'The "client_version" value is not the same (which is fine)' );
    };
};

subtest 'check historic tests' => sub {
    # Verifies that delegated and undelegated tests are coded correctly when started
    # and that the filter option in "domain_history" works correctly

    my $domain          = 'xa';
    # Non-batch for "job_create":
    my $params_un1      = { # undelegated, non-batch
        domain          => $domain,
        nameservers     => [
            { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
            ],
    };
    my $params_un2      = { # undelegated, non-batch
        domain          => $domain,
        ds_info         => [
            { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
            ],
    };
    my $params_dn1 = { # delegated, non-batch
        domain          => $domain,
    };
    # Batch for "batch_create"
    my $domain2         = 'xb';
    my $params_ub1      = { # undelegated, batch
        domains         => [ $domain, $domain2 ],
        test_params     => {
            nameservers => [
                { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
                ],
        },
    };
    my $params_ub2      = { # undelegated, batch
        domains         => [ $domain, $domain2 ],
        test_params     => {
            ds_info     => [
                { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
                ],
        },
    };
    my $params_db1      = { # delegated, batch
        domains         => [ $domain, $domain2 ],
    };
    # The batch jobs, $params_ub1, $params_ub2 and $params_db1, cannot be run from here due to limitation in the API. See issue #827.

    foreach my $param ($params_un1, $params_un2, $params_dn1) {
        my $job_res = $rpcapi->job_create( $param );
        my $testid = $job_res->{job_id};
        ok( $testid, "API job_create ID OK" );
        diag "running the agent on test $testid";
        $agent->run( $testid );
        my $res_job_status = $rpcapi->job_status( { test_id => $testid } );
        is( $res_job_status->{progress}, 100 , 'API job_status -> Test finished' );
    };

    my $res_domain_history_delegated = $rpcapi->domain_history(
        {
            filter => 'delegated',
            frontend_params => {
                domain => $domain,
            }
        } );
    my $res_domain_history_undelegated = $rpcapi->domain_history(
        {
            filter => 'undelegated',
            frontend_params => {
                domain => $domain,
            }
        } );
    my $domain_history_delegated = $res_domain_history_delegated->{history};
    my $domain_history_undelegated = $res_domain_history_undelegated->{history};

    # diag explain( $domain_history_delegated );
    is( scalar( @$domain_history_delegated ), 1, 'One delegated test created' );
    # diag explain( $domain_history_undelegated );
    is( scalar( @$domain_history_undelegated ), 2, 'Two undelegated tests created' );

    subtest 'domain is case and trailing dot insensitive' => sub {
        my $res_domain_history_delegated = $rpcapi->domain_history(
            {
                filter => 'delegated',
                frontend_params => {
                    domain => $domain . '.',
                }
            } );
        my $res_domain_history_undelegated = $rpcapi->domain_history(
            {
                filter => 'undelegated',
                frontend_params => {
                    domain => ucfirst( $domain ),
                }
            } );
        my $domain_history_delegated = $res_domain_history_delegated->{history};
        my $domain_history_undelegated = $res_domain_history_undelegated->{history};

        is( scalar( @$domain_history_delegated ), 1, 'One delegated test created' );
        is( scalar( @$domain_history_undelegated ), 2, 'Two undelegated tests created' );
    };
};

subtest 'normalize "domain" column' => sub {
    my %domains_to_test = (
        "aFnIc.Fr"  => "afnic.fr",
        "afnic.fr." => "afnic.fr",
        "aFnic.Fr." => "afnic.fr"
    );

    my $test_params = {
        client_id      => 'Unit Test',
        client_version => '1.0',
    };

    while ( my ($domain, $expected) = each (%domains_to_test) ) {
        $test_params->{domain} = $domain;

        my $job_res = $rpcapi->job_create( $test_params );
        $hash_id = $job_res->{job_id};
        my ( $db_domain ) = $dbh->selectrow_array( "SELECT domain FROM test_results WHERE hash_id=?", undef, $hash_id );
        is( $db_domain, $expected, 'stored domain name is normalized' );
    }
};

TestUtil::save_datafile( $datafile );

done_testing();

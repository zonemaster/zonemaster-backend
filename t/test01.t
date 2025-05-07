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

my $configuration = <<"EOF";
[DB]
engine = $db_backend

[MYSQL]
host     = localhost
user     = zonemaster_test
password = zonemaster
database = zonemaster_test

[POSTGRESQL]
host     = localhost
user     = zonemaster_test
password = zonemaster
database = zonemaster_test

[SQLITE]
database_file = $tempdir/zonemaster.sqlite

[LANGUAGE]
locale = en_US
EOF

if ( $ENV{ZONEMASTER_RECORD} ) {
  $configuration .= <<"EOF";
[PUBLIC PROFILES]
test_profile=$t_path/test_profile_network_true.json
default=$t_path/test_profile_network_true.json
EOF
} else {
  $configuration .= <<"EOF";
[PUBLIC PROFILES]
test_profile=$t_path/test_profile_no_network.json
default=$t_path/test_profile_no_network.json
EOF
}

my $config = Zonemaster::Backend::Config->parse( $configuration );

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
    $hash_id = $rpcapi->start_domain_test( $params );

    ok( $hash_id, "API start_domain_test OK" );
    is( length($hash_id), 16, "Test has a 16 characters length hash ID (hash_id=$hash_id)" );

    my ( $test_id_db, $hash_id_db ) = $dbh->selectrow_array( "SELECT id, hash_id FROM test_results WHERE id=?", undef, $test_id );
    is( $test_id_db, $test_id , 'API start_domain_test -> Test inserted in the DB' );
    is( $hash_id_db, $hash_id , 'Correct hash_id in database' );

    # test test_progress API
    my $progress = $rpcapi->test_progress( { test_id => $hash_id } );
    is( $progress, 0 , 'Test has been created, its progress is 0' );
};

subtest 'get and run test' => sub {
    my ( $hash_id_from_db ) = $rpcapi->{db}->get_test_request();
    is( $hash_id_from_db, $hash_id, 'Get correct test to run' );

    my $progress = $rpcapi->test_progress( { test_id => $hash_id } );
    is( $progress, 1, 'Test has been picked, its progress is 1' );

    diag "running the agent on test $hash_id";
    $agent->run( $hash_id ); # blocking call

    $progress = $rpcapi->test_progress( { test_id => $hash_id } );
    is( $progress, 100 , 'Test has finished, its progress is 100' );
};

subtest 'API calls' => sub {

    subtest 'get_test_results' => sub {
        local $@ = undef;
        my $res = eval { $rpcapi->get_test_results( { id => $hash_id, language => 'en' } ) };
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

    subtest 'get_test_params' => sub {
        my $res = $rpcapi->get_test_params( { test_id => $hash_id } );
        is( $res->{domain}, $params->{domain}, 'Retrieve the correct "domain" value' );
        is( $res->{profile}, $params->{profile}, 'Retrieve the correct "profile" value' );
        is( $res->{client_id}, $params->{client_id}, 'Retrieve the correct "client_id" value' );
        is( $res->{client_version}, $params->{client_version}, 'Retrieve the correct "client_version" value' );
        is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
        is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );
        is_deeply( $res->{nameservers}, $params->{nameservers}, 'Retrieve the correct "nameservers" value' );
        is_deeply( $res->{ds_info}, $params->{ds_info}, 'Retrieve the correct "ds_info" value' );
    };

    subtest 'add_api_user' => sub {
        my $res;
        eval {
            $res = $rpcapi->add_api_user( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } );
        };
        is( $res, 1, 'API add_api_user success');

        my $user_check_query = q/SELECT * FROM users WHERE username = 'zonemaster_test'/;
        is( scalar( $dbh->selectrow_array( $user_check_query ) ), 1 ,'API add_api_user user created' );
    };

    subtest 'version_info' => sub {
        my $res = $rpcapi->version_info();
        ok( defined( $res->{zonemaster_ldns} ), 'Has a "zonemaster_ldns" key' );
        ok( defined( $res->{zonemaster_engine} ), 'Has a "zonemaster_engine" key' );
        ok( defined( $res->{zonemaster_backend} ), 'Has a "zonemaster_backend" key' );
    };

    subtest 'profile_names' => sub {
        my $res = $rpcapi->profile_names();
        is( scalar( @$res ), 2, 'There are exactly 2 public profiles' );
        ok( grep( /default/, @$res ), 'The profile "default" is defined' );
        ok( grep( /test_profile/, @$res ), 'The profile "test_profile" is defined' );
    };

    subtest 'get_data_from_parent_zone' => sub {
        my $res = $rpcapi->get_data_from_parent_zone( { domain => "fr" } );
        note explain( $res );
        ok( defined( $res->{ns_list} ), 'Has a list of nameservers' );
        ok( defined( $res->{ds_list} ), 'Has a list of DS records' );

        my @ns_list = map { $_->{ns} } @{ $res->{ns_list} };
        ok( grep( /d\.nic\.fr/, @ns_list ), 'Has "d.nic.fr" nameserver' );
        ok( grep( /f\.ext\.nic\.fr/, @ns_list ), 'Has "f.ext.nic.fr" nameserver' );
        ok( grep( /g\.ext\.nic\.fr/, @ns_list ), 'Has "g.ext.nic.fr" nameserver' );

        my @ip_list = map { $_->{ip} } @{ $res->{ns_list} };
        ok( grep( /194\.0\.9\.1/, @ip_list ), 'Has "194.0.9.1" ip' ); # d.nic.fr
        ok( grep( /2001:678:c::1/, @ip_list ), 'Has "2001:678:c::1" ip' );
        ok( grep( /194\.0\.36\.1/, @ip_list ), 'Has "194.0.36.1" ip' ); # g.ext.nic.fr
        ok( grep( /2001:678:4c::1/, @ip_list ), 'Has "2001:678:4c::1" ip' );
        ok( grep( /194\.146\.106\.46/, @ip_list ), 'Has "194.146.106.46" ip' ); # f.ext.nic.fr
        ok( grep( /2001:67c:1010:11::53/, @ip_list ), 'Has "2001:67c:1010:11::53" ip' );

        my $ds_value = {
            'algorithm' => 13,
            'digest' => '1303e8da8fb60db500d5bea1ee5dc9a2bcc93dfe2fc43d346576658feccf5749', # must match case
            'digtype' => 2,
            'keytag' => 29133
        };
        is( scalar( @{ $res->{ds_list} } ), 1, 'Has only one DS set' );
        is_deeply( $res->{ds_list}[0], $ds_value, 'Has correct DS values' );
    };

};

# start a second test with IPv6 disabled
$params->{ipv6} = 0;
$hash_id = $rpcapi->start_domain_test( $params );
$rpcapi->{db}->claim_test( $hash_id )
  or BAIL_OUT( "test needs to be claimed before calling run()" );
diag "running the agent on test $hash_id";
$agent->run($hash_id);

subtest 'second test has IPv6 disabled' => sub {
    my $res = $rpcapi->get_test_params( { test_id => $hash_id } );
    is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
    is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );

    $res = $rpcapi->get_test_results( { id => $hash_id, language => 'en' } );
    my @msgs = map { $_->{message} } @{ $res->{results} };
    ok( grep( /IPv6 is disabled/, @msgs ), 'Results contain an "IPv6 is disabled" message' );
};

my $test_history;
subtest 'get_test_history' => sub {
    my $offset = 0;
    my $limit  = 10;
    my $method_params = {
        frontend_params => { domain => $params->{domain} },
        offset => $offset,
        limit => $limit
    };

    $test_history = $rpcapi->get_test_history( $method_params );
    note explain( $test_history );
    is( scalar( @$test_history ), 2, 'Two tests created' );

    foreach my $res (@$test_history) {
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
        $rpcapi->start_domain_test( $params );
        ( $hash_id ) = $rpcapi->{db}->get_test_request();

        $test_history = $rpcapi->get_test_history( $method_params );
        note explain( $test_history );
        is( scalar( @$test_history ), 2, 'Only 2 tests should be retrieved' );

        # now run the test
        diag "running the agent on test $hash_id";
        $agent->run( $hash_id );

        $test_history = $rpcapi->get_test_history( $method_params );
        is( scalar( @$test_history ), 3, 'Now 3 tests should be retrieved' );
    }
};

subtest 'mock another client (i.e. reuse a previous test)' => sub {
    $params->{client_id} = 'Another Client';
    $params->{client_version} = '0.1';

    my $new_hash_id = $rpcapi->start_domain_test( $params );

    is( $new_hash_id, $hash_id, 'Has the same hash than previous test' );

    subtest 'check test_params values' => sub {
        my $res = $rpcapi->get_test_params( { test_id => "$hash_id" } );
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
    # and that the filter option in "get_test_history" works correctly

    my $domain          = 'xa';
    # Non-batch for "start_domain_test":
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
    # Batch for "add_batch_job"
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
        my $testid = $rpcapi->start_domain_test( $param );
        ok( $testid, "API start_domain_test ID OK" );
        $rpcapi->{db}->claim_test( $testid )
          or BAIL_OUT( "test needs to be claimed before calling run()" );
        diag "running the agent on test $testid";
        $agent->run( $testid );
        is( $rpcapi->test_progress( { test_id => $testid } ), 100 , 'API test_progress -> Test finished' );
    };

    my $test_history_delegated = $rpcapi->get_test_history(
        {
            filter => 'delegated',
            frontend_params => {
                domain => $domain,
            }
        } );
    my $test_history_undelegated = $rpcapi->get_test_history(
        {
            filter => 'undelegated',
            frontend_params => {
                domain => $domain,
            }
        } );

    note explain( $test_history_delegated );
    is( scalar( @$test_history_delegated ), 1, 'One delegated test created' );
    note explain( $test_history_undelegated );
    is( scalar( @$test_history_undelegated ), 2, 'Two undelegated tests created' );

    subtest 'domain is case and trailing dot insensitive' => sub {
        my $test_history_delegated = $rpcapi->get_test_history(
            {
                filter => 'delegated',
                frontend_params => {
                    domain => $domain . '.',
                }
            } );
        my $test_history_undelegated = $rpcapi->get_test_history(
            {
                filter => 'undelegated',
                frontend_params => {
                    domain => ucfirst( $domain ),
                }
            } );

        is( scalar( @$test_history_delegated ), 1, 'One delegated test created' );
        is( scalar( @$test_history_undelegated ), 2, 'Two undelegated tests created' );
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

        $hash_id = $rpcapi->start_domain_test( $test_params );
        my ( $db_domain ) = $dbh->selectrow_array( "SELECT domain FROM test_results WHERE hash_id=?", undef, $hash_id );
        is( $db_domain, $expected, 'stored domain name is normalized' );
    }
};

TestUtil::save_datafile( $datafile );

done_testing();

use strict;
use warnings;
use 5.14.2;

use Cwd;
use Data::Dumper;
use File::Temp qw[tempdir];
use JSON::PP;
use Test::Exception;
use Test::More;    # see done_testing()

use Zonemaster::Engine;

=head1 ENVIRONMENT

=head2 TARGET

Set the database to use.
Can be C<SQLite>, C<MySQL> or C<PostgreSQL>.
Default to C<SQLite>.

=head2 ZONEMASTER_RECORD

If set, the data from the test is recorded to a file. Otherwise the data is
loaded from a file.

=cut

# Use the TARGET environment variable to set the database to use
# default to SQLite
my $db_backend = $ENV{TARGET};
if ( not $db_backend ) {
    $db_backend = 'SQLite';
} elsif ( $db_backend !~ /^(?:SQLite|MySQL|PostgreSQL)$/ ) {
    BAIL_OUT( "Unsupported database backend: $db_backend" );
}

diag "database: $db_backend";

my $tempdir = tempdir( CLEANUP => 1 );

my $datafile = q{t/test01.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine->preload_cache( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
    diag "not recording";
} else {
    diag "recording";
}

# Require Zonemaster::Backend::RPCAPI.pm test
use_ok( 'Zonemaster::Backend::RPCAPI' );

use_ok( 'Zonemaster::Backend::Config' );

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

# Create Zonemaster::Backend::RPCAPI object
my $backend;
eval {
    $backend = Zonemaster::Backend::RPCAPI->new(
        {
            dbtype => $db_backend,
            config => $config,
        }
    );
};
if ( $@ ) {
    diag explain( $@ );
    BAIL_OUT( 'Could not connect to database' );
}

isa_ok( $backend, 'Zonemaster::Backend::RPCAPI' );

my $dbh = $backend->{db}->dbh;

# prepare the database
$backend->{db}->drop_tables();
$backend->{db}->create_schema();

# Create the agent
use_ok( 'Zonemaster::Backend::TestAgent' );
my $agent = Zonemaster::Backend::TestAgent->new( { dbtype => "$db_backend", config => $config } );
isa_ok($agent, 'Zonemaster::Backend::TestAgent', 'agent');


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
    $hash_id = $backend->start_domain_test( $params );

    ok( $hash_id, "API start_domain_test OK" );
    is( length($hash_id), 16, "Test has a 16 characters length hash ID (hash_id=$hash_id)" );

    my ( $test_id_db, $hash_id_db ) = $dbh->selectrow_array( "SELECT id, hash_id FROM test_results WHERE id=?", undef, $test_id );
    is( $test_id_db, $test_id , 'API start_domain_test -> Test inserted in the DB' );
    is( $hash_id_db, $hash_id , 'Correct hash_id in database' );

    # test test_progress API
    my $progress = $backend->test_progress( { test_id => $hash_id } );
    is( $progress, 0 , 'Test has been created, its progress is 0' );
};

subtest 'get and run test' => sub {
    my $hash_id_from_db = $backend->{db}->get_test_request();
    is( $hash_id_from_db, $hash_id, 'Get correct test to run' );

    my $progress = $backend->test_progress( { test_id => $hash_id } );
    is( $progress, 1, 'Test has been picked, its progress is 1' );

    diag "running the agent on test $hash_id";
    $agent->run( $hash_id ); # blocking call

    $progress = $backend->test_progress( { test_id => $hash_id } );
    is( $progress, 100 , 'Test has finished, its progress is 100' );
};

subtest 'API calls' => sub {

    subtest 'get_test_results' => sub {
        my $res = $backend->get_test_results( { id => $hash_id, language => 'en_US' } );
        is( $res->{id}, $test_id, 'Retrieve the correct "id"' );
        is( $res->{hash_id}, $hash_id, 'Retrieve the correct "hash_id"' );
        ok( defined $res->{params}, 'Value "params" properly defined' );
        ok( defined $res->{creation_time}, 'Value "creation_time" properly defined' );
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
        my $res = $backend->get_test_params( { test_id => $hash_id } );
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
            $res = $backend->add_api_user( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } );
        };
        is( $res, 1, 'API add_api_user success');

        my $user_check_query = q/SELECT * FROM users WHERE username = 'zonemaster_test'/;
        is( scalar( $dbh->selectrow_array( $user_check_query ) ), 1 ,'API add_api_user user created' );
    };

    subtest 'version_info' => sub {
        my $res = $backend->version_info();
        ok( defined( $res->{zonemaster_engine} ), 'Has a "zonemaster_engine" key' );
        ok( defined( $res->{zonemaster_backend} ), 'Has a "zonemaster_backend" key' );
    };

    subtest 'profile_names' => sub {
        my $res = $backend->profile_names();
        is( scalar( @$res ), 2, 'There are exactly 2 public profiles' );
        ok( grep( /default/, @$res ), 'The profile "default" is defined' );
        ok( grep( /test_profile/, @$res ), 'The profile "test_profile" is defined' );
    };

    subtest 'get_data_from_parent_zone' => sub {
        my $res = $backend->get_data_from_parent_zone( { domain => "fr" } );
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

    # TODO add_batch_job
    subtest 'get_batch_job_result' => sub {
        subtest 'unknown batch' => sub {
            dies_ok {
                $backend->get_batch_job_result( { batch_id => 10 } );
            };
            my $res = $@;
            is( $res->{error}, "Zonemaster::Backend::Error::ResourceNotFound", 'Correct error type' );
        };

        # TODO get_batch_job_result with known batch
    };
};

# start a second test with IPv6 disabled
$params->{ipv6} = 0;
$hash_id = $backend->start_domain_test( $params );
diag "running the agent on test $hash_id";
$agent->run($hash_id);

subtest 'second test has IPv6 disabled' => sub {
    my $res = $backend->get_test_params( { test_id => $hash_id } );
    is( $res->{ipv4}, $params->{ipv4}, 'Retrieve the correct "ipv4" value' );
    is( $res->{ipv6}, $params->{ipv6}, 'Retrieve the correct "ipv6" value' );

    $res = $backend->get_test_results( { id => $hash_id, language => 'en_US' } );
    my @msg_basic = map { $_->{message} if $_->{module} eq 'BASIC' } @{ $res->{results} };
    ok( grep( /IPv6 is disabled/, @msg_basic ), 'Results contain an "IPv6 is disabled" message' );
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

    $test_history = $backend->get_test_history( $method_params );
    #diag explain( $test_history );
    is( scalar( @$test_history ), 2, 'Two tests created' );

    foreach my $res (@$test_history) {
        is( length($res->{id}), 16, 'Test has 16 characters length hash ID' );
        is( $res->{undelegated}, JSON::PP::true, 'Test is undelegated' );
        ok( defined $res->{creation_time}, 'Value "creation_time" properly defined' );
        ok( defined $res->{created_at}, 'Value "created_at" properly defined' );
        ok( defined $res->{overall_result}, 'Value "overall_result" properly defined' );
    }

    subtest 'include finished tests only' => sub {
        # start a thirs test with IPv4 disabled
        $params->{ipv6} = 1;
        $params->{ipv4} = 0;

        # create the test, retrieve its id but we don't run it
        $backend->start_domain_test( $params );
        $hash_id = $backend->{db}->get_test_request();

        $test_history = $backend->get_test_history( $method_params );
        #diag explain( $test_history );
        is( scalar( @$test_history ), 2, 'Only 2 tests should be retrieved' );

        # now run the test
        diag "running the agent on test $hash_id";
        $agent->run( $hash_id );

        $test_history = $backend->get_test_history( $method_params );
        is( scalar( @$test_history ), 3, 'Now 3 tests should be retrieved' );
    }
};

subtest 'mock another client (i.e. reuse a previous test)' => sub {
    $params->{client_id} = 'Another Client';
    $params->{client_version} = '0.1';

    my $new_hash_id = $backend->start_domain_test( $params );

    is( $new_hash_id, $hash_id, 'Has the same hash than previous test' );

    subtest 'check test_params values' => sub {
        my $res = $backend->get_test_params( { test_id => "$hash_id" } );
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
        my $testid = $backend->start_domain_test( $param );
        ok( $testid, "API start_domain_test ID OK" );
        diag "running the agent on test $testid";
        $agent->run( $testid );
        is( $backend->test_progress( { test_id => $testid } ), 100 , 'API test_progress -> Test finished' );
    };

    my $test_history_delegated = $backend->get_test_history(
        {
            filter => 'delegated',
            frontend_params => {
                domain => $domain,
            }
        } );
    my $test_history_undelegated = $backend->get_test_history(
        {
            filter => 'undelegated',
            frontend_params => {
                domain => $domain,
            }
        } );

    # diag explain( $test_history_delegated );
    is( scalar( @$test_history_delegated ), 1, 'One delegated test created' );
    # diag explain( $test_history_undelegated );
    is( scalar( @$test_history_undelegated ), 2, 'Two undelegated tests created' );
};

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine->save_cache( $datafile );
}

done_testing();

if ( $db_backend eq 'SQLite' ) {
    my $dbfile = $dbh->sqlite_db_filename;
    if ( -e $dbfile and -M $dbfile < 0 and -o $dbfile ) {
        unlink $dbfile;
    }
}

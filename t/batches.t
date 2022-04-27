use strict;
use warnings;
use 5.14.2;

use Cwd;
use Data::Dumper;
use File::Temp qw[tempdir];
use JSON::PP;
use POSIX qw( strftime );
use Time::Local qw( timelocal_modern );
use Test::Exception;
use Test::More;    # see done_testing()

use Zonemaster::Engine;

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

my $datafile = q{t/batches.data};
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

my $config = <<EOF;
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

my $user = {
    username => 'user',
    api_key => 'key'
};

# define the default properties for the tests
my $params = {
    client_id      => 'Unit Test',
    client_version => '1.0',
    ipv4           => JSON::PP::true,
    ipv6           => JSON::PP::true,
    profile        => 'test_profile',
};

# Create Zonemaster::Backend::RPCAPI object
sub init_from_config {
    my ( $db_backend, $config ) = @_;

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

    # prepare the database
    $backend->{db}->drop_tables();
    $backend->{db}->create_schema();

    # create a user
    $backend->add_api_user( $user );

    return $backend;
}

sub to_timestamp {
    my ( $date ) = @_;

    my ( $year, $month, $day, $hour, $min, $sec ) = split( /[\s:-]+/, $date );
    my $time = timelocal_modern( $sec, $min, $hour, $day, $month-1, $year );
    return $time;
}

sub check_tolerance {
    my ( $ref_time, $msg ) = @_;

    my $current_time = strftime "%Y-%m-%d %H:%M:%S", gmtime( time() );
    my $delta = abs( to_timestamp($current_time) - to_timestamp($ref_time) );

    my $tolerance = 60; # 1 minute is tolerable between ret_time and current_time

    cmp_ok( $delta, '<=', $tolerance, $msg);
}

subtest 'RPCAPI add_batch_job' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $backend = init_from_config( $db_backend, $config );
    my $dbh = $backend->{db}->dbh;

    my @domains = ( 'afnic.fr' );

    my $res = $backend->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $res, 1, 'correct batch job id returned' );

    subtest 'table "batch_jobs" contains an entry' => sub {
        my ( $count ) = $dbh->selectrow_array( q[ SELECT count(*) FROM batch_jobs ] );
        is( $count, 1, 'one row in table' );

        my ( $id, $username, $created_at ) = $dbh->selectrow_array( q[ SELECT * FROM batch_jobs ]);
        is( $id, 1, 'first batch id is 1' );
        is( $username, $user->{username}, 'correct batch user' );
        ok( $created_at, 'defined creation time' );
        check_tolerance( $created_at, 'creation time in tolerance zone' );
    };

    subtest 'table "test_results" contains an entry' => sub {
        my ( $count ) = $dbh->selectrow_array( q[ SELECT count(*) FROM test_results ] );
        is( $count, 1, 'one row in table' );

        my ( $hash_id, $domain, $batch_id, $created_at, $started_at, $ended_at, $params ) = $dbh->selectrow_array(
            q[
                SELECT
                    hash_id,
                    domain,
                    batch_id,
                    created_at,
                    started_at,
                    ended_at,
                    params
                FROM test_results
            ]
        );

        is( length($hash_id), 16, 'correct hash_id length' );
        is( $domain, $domains[0], 'correct domain' );
        is( $batch_id, 1, 'correct batch_id' );
        ok( $created_at, 'defined creation time' );
        check_tolerance( $created_at, 'creation time in tolerance zone' );
        ok( ! defined $started_at, 'undefined start time' );
        ok( ! defined $ended_at, 'undefined end time' );
    };
};

subtest 'RPCAPI get_batch_job_result' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $backend = init_from_config( $db_backend, $config );

    my @domains = ( 'afnic.fr' );

    my $batch_id = $backend->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $batch_id, 1, 'correct batch job id returned' );

    my $res = $backend->get_batch_job_result( { batch_id => $batch_id } );

    is( $res->{nb_running}, @domains, 'correct number of runninng tests' );
    is( $res->{nb_finished}, 0, 'correct number of finished tests' );
};

subtest 'batch with several domains' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $backend = init_from_config( $db_backend, $config );
    my $dbh = $backend->{db}->dbh;

    my @domains = sort( 'afnic.fr', 'iis.se' );

    my $res = $backend->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $res, 1, 'correct batch job id returned' );

    $res = $backend->get_batch_job_result( { batch_id => 1 } );

    is( $res->{nb_running}, @domains, 'correct number of runninng tests' );
    is( $res->{nb_finished}, 0, 'correct number of finished tests' );

    subtest 'table "test_results" contains 2 entries' => sub {
        my ( $count ) = $dbh->selectrow_array( q[ SELECT count(*) FROM test_results ] );
        is( $count, @domains, 'two rows in table' );

        my $rows = $dbh->selectall_hashref(
            q[
                SELECT
                    hash_id,
                    domain,
                    batch_id,
                    created_at,
                    started_at,
                    ended_at,
                    params
                FROM test_results
            ],
            'domain'
        );

        my @keys = sort keys %$rows;
        is_deeply( \@keys, \@domains, 'correct domains' );

        foreach my $domain ( @keys ) {
            is( length($rows->{$domain}->{hash_id}), 16, "[$domain] correct hash_id length" );
            is( $rows->{$domain}->{batch_id}, 1, "[$domain] correct batch_id" );
            ok( $rows->{$domain}->{created_at}, "[$domain] defined creation time" );
            check_tolerance( $rows->{$domain}->{created_at}, "[$domain] creation time in tolerance zone" );
            ok( ! defined $rows->{$domain}->{started_at}, "[$domain] undefined start time" );
            ok( ! defined $rows->{$domain}->{ended_at}, "[$domain] undefined end time" );
        }
    };
};

subtest 'batch job still running' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $backend = init_from_config( $db_backend, $config );
    my $dbh = $backend->{db}->dbh;

    my @domains = ( 'afnic.fr' );

    my $batch_id = $backend->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $batch_id, 1, 'correct batch job id returned' );

    dies_ok {
        my $new_batch_id = $backend->add_batch_job(
            {
                %$user,
                domains => \@domains,
                test_params => $params
            }
        );
    } 'a batch is already running for the user, new batch creation should fail' ;
    my $res = $@;
    is( $res->{message}, 'Batch job still running', 'correct error message' );
    is( $res->{data}->{batch_id}, $batch_id, 'error returned current running batch id' );
    ok( $res->{data}->{creation_time}, 'error data contains batch creation time' );

    subtest 'use another user' => sub {
        my $another_user = { username => 'another', api_key => 'token' };
        $backend->add_api_user( $another_user );
        my $batch_id = $backend->add_batch_job(
            {
                %$another_user,
                domains => \@domains,
                test_params => $params
            }
        );

        is( $batch_id, 2, 'another_user can create another batch' );
    };
};

# TODO: create an agent and run batch tests

## Create the agent
#use_ok( 'Zonemaster::Backend::TestAgent' );
#my $agent = Zonemaster::Backend::TestAgent->new( { dbtype => "$db_backend", config => $config } );
#isa_ok($agent, 'Zonemaster::Backend::TestAgent', 'agent');

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine->save_cache( $datafile );
}

done_testing();

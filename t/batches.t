use strict;
use warnings;
use 5.14.2;

use Cwd;
use Data::Dumper;
use File::Temp qw[tempdir];
use POSIX qw( strftime );
use Time::Local qw( timelocal_modern );
use Test::Exception;
use Test::More;    # see done_testing()

my $t_path;
BEGIN {
    use File::Spec::Functions qw( rel2abs );
    use File::Basename qw( dirname );
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;
use TestUtil;

use Zonemaster::Backend::Config;

my $db_backend = TestUtil::db_backend();

my $tempdir = tempdir( CLEANUP => 1 );

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
sub init_backend {
    my ( $config ) = @_;

    my $rpcapi = TestUtil::create_rpcapi( $config );

    # create a user
    $rpcapi->add_api_user( $user );

    return $rpcapi;
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
    my $rpcapi = init_backend( $config );
    my $dbh = $rpcapi->{db}->dbh;

    my @domains = ( 'afnic.fr' );

    my $res = $rpcapi->add_batch_job(
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
    my $rpcapi = init_backend( $config );
    subtest 'batch job exists' => sub {
        my @domains = ( 'afnic.fr' );

        my $batch_id = $rpcapi->add_batch_job(
            {
                %$user,
                domains => \@domains,
                test_params => $params
            }
        );

        is( $batch_id, 1, 'correct batch job id returned' );

        my $res = $rpcapi->get_batch_job_result( { batch_id => $batch_id } );

        is( $res->{nb_running}, @domains, 'correct number of runninng tests' );
        is( $res->{nb_finished}, 0, 'correct number of finished tests' );
    };

    subtest 'unknown batch' => sub {
        my $unknown_batch = 10;
        dies_ok {
            $rpcapi->get_batch_job_result( { batch_id => $unknown_batch } );
        };
        my $res = $@;
        is( $res->{error}, 'Zonemaster::Backend::Error::ResourceNotFound', 'correct error type' );
        is( $res->{message}, 'Unknown batch', 'correct error message' );
        is( $res->{data}->{batch_id}, $unknown_batch, 'correct data type returned' );
    };
};

subtest 'batch with several domains' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $rpcapi = init_backend( $config );
    my $dbh = $rpcapi->{db}->dbh;

    my @domains = sort( 'afnic.fr', 'iis.se' );

    my $res = $rpcapi->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $res, 1, 'correct batch job id returned' );

    $res = $rpcapi->get_batch_job_result( { batch_id => 1 } );

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
    my $rpcapi = init_backend( $config );
    my $dbh = $rpcapi->{db}->dbh;

    my @domains = ( 'afnic.fr' );

    my $batch_id = $rpcapi->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    is( $batch_id, 1, 'correct batch job id returned' );

    dies_ok {
        my $new_batch_id = $rpcapi->add_batch_job(
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
        $rpcapi->add_api_user( $another_user );
        my $batch_id = $rpcapi->add_batch_job(
            {
                %$another_user,
                domains => \@domains,
                test_params => $params
            }
        );

        is( $batch_id, 2, 'another_user can create another batch' );
    };
};

subtest 'duplicate user should fail' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $rpcapi = init_backend( $config );

    dies_ok {
        $rpcapi->add_api_user( { username => $user->{username}, api_key => "another api key" } );
    };
    my $res = $@;
    is( $res->{error}, 'Zonemaster::Backend::Error::Conflict', 'correct error type' );
    is( $res->{message}, 'User already exists', 'correct error message' );
    is( $res->{data}->{username}, $user->{username}, 'correct data type returned' );
};

subtest 'normalize "domain" column' => sub {
    my $config = Zonemaster::Backend::Config->parse( $config );
    my $rpcapi = init_backend( $config );
    my $dbh = $rpcapi->{db}->dbh;

    my %domains_to_test = (
        "aFnIc.Fr"  => "afnic.fr",
        "afnic.fr." => "afnic.fr",
        "aFnic.Fr." => "afnic.fr"
    );
    my @domains = keys %domains_to_test;

    my $batch_id = $rpcapi->add_batch_job(
        {
            %$user,
            domains => \@domains,
            test_params => $params
        }
    );

    my @db_domain = map { $$_[0] } $dbh->selectall_array( "SELECT domain FROM test_results WHERE batch_id=?", undef, $batch_id );

    # FIXME: batch jobs do not reuse tests yet,
    #        hence 3 exactly identical tests are created
    is( @db_domain, 3, '3 tests created' );
    my @expected = values %domains_to_test;
    is_deeply( \@db_domain, \@expected, 'domains are normalized' );
};

# TODO: create an agent and run batch tests

## Create the agent
#use_ok( 'Zonemaster::Backend::TestAgent' );
#my $agent = Zonemaster::Backend::TestAgent->new( { dbtype => "$db_backend", config => $config } );
#isa_ok($agent, 'Zonemaster::Backend::TestAgent', 'agent');

done_testing();

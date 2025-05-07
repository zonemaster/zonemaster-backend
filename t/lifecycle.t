use strict;
use warnings;
use 5.14.2;

use Test::More tests => 2;
use Test::Exception;
use Test::NoWarnings;
use Log::Any::Test;
use Log::Any qw( $log );

my $TIME;
BEGIN {
    $TIME = CORE::time();

    *CORE::GLOBAL::time = sub { $TIME };
}

use Data::Dumper;
use File::ShareDir qw[dist_file];
use File::Temp qw[tempdir];

my $t_path;
BEGIN {
    use File::Spec::Functions qw( rel2abs );
    use File::Basename qw( dirname );
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;
use TestUtil;

use Zonemaster::Engine;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB qw( $TEST_WAITING $TEST_RUNNING $TEST_COMPLETED );

sub advance_time {
    my ( $delta ) = @_;
    $TIME += $delta;
}

my $db_backend = TestUtil::db_backend();

my $tempdir = tempdir( CLEANUP => 1 );
my $config = Zonemaster::Backend::Config->parse( <<EOF );
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

[ZONEMASTER]
age_reuse_previous_test = 10
EOF

sub count_cancellation_messages {
    my $results = shift;
    return scalar grep { $_->{tag} eq 'UNABLE_TO_FINISH_TEST' } @{ $results->{results} };
}

sub count_died_messages {
    my $results = shift;
    return scalar grep { $_->{tag} eq 'TEST_DIED' } @{ $results->{results} };
}

subtest 'Everything but Test::NoWarnings' => sub {
    lives_ok {    # Make sure we get to print log messages in case of errors.
        my $db = TestUtil::init_db( $config );

        subtest 'State transitions' => sub {
            my $testid1 = $db->create_new_test( "1.transition.test", {}, 10 );
            is ref $testid1, '', "create_new_test should return 'testid' scalar";
            my $current_state = $db->test_state( $testid1 );
            is $current_state, $TEST_WAITING, "New test starts out in 'waiting' state.";

            my @cases = (
                {
                    old_state  => $TEST_WAITING,
                    transition => [ 'store_results', '{}' ],
                    throws     => qr/illegal transition/,
                },
                {
                    old_state  => $TEST_WAITING,
                    transition => ['claim_test'],
                    returns    => 1,                # true
                    new_state  => $TEST_RUNNING,
                },
                {
                    old_state  => $TEST_RUNNING,
                    transition => ['claim_test'],
                    returns    => '',               # false
                },
                {
                    old_state  => $TEST_RUNNING,
                    transition => [ 'store_results', '{}' ],
                    returns    => undef,
                    new_state  => $TEST_COMPLETED,
                },
                {
                    old_state  => $TEST_COMPLETED,
                    transition => ['claim_test'],
                    returns    => '',                #false
                },
                {
                    old_state  => $TEST_COMPLETED,
                    transition => [ 'store_results', '{}' ],
                    throws     => qr/illegal transition/,
                },
            );

            for my $case ( @cases ) {
                if ( $case->{old_state} ne $current_state ) {
                    BAIL_OUT( "Assuming to be in '$case->{old_state}' but we're actually in '$current_state'!" );
                }

                my ( $transition, @args ) = @{ $case->{transition} };

                if ( exists $case->{returns} ) {
                    my $rv_string = Data::Dumper->new( [ $case->{returns} ] )->Indent( 0 )->Terse( 1 )->Dump;

                    my $result = $db->$transition( $testid1, @args );
                    is $result,
                      $case->{returns},
                      "In state '$case->{old_state}' transition '$transition' should return $rv_string,";

                    if ( $case->{new_state} ) {
                        $current_state = $db->test_state( $testid1 );
                        is $current_state,
                          $case->{new_state},
                          "and it should move the test to '$case->{new_state}' state.";
                    }
                    else {
                        $current_state = $db->test_state( $testid1 );
                        is $current_state,
                          $case->{old_state},
                          "and it should not affect the actual state.";
                    }
                }
                elsif ( exists $case->{throws} ) {
                    throws_ok {
                        $db->$transition( $testid1, @args )
                    }
                    $case->{throws}, "In state '$case->{old_state}' transition '$transition' should throw an exception,";

                    $current_state = $db->test_state( $testid1 );
                    is $current_state,
                      $case->{old_state},
                      "and it should not affect the actual state.";
                }
                else {
                    BAIL_OUT( "Invalid case specification!" );
                }
            }
        };

        subtest 'Progress' => sub {
            my $testid1 = $db->create_new_test( "1.progress.test", {}, 10 );
            is ref $testid1, '', "create_new_test should return 'testid' scalar";

            throws_ok { $db->test_progress( $testid1, 1 ) } qr/illegal update/, "Setting progress should throw an exception in 'waiting' state.";

            $db->claim_test( $testid1 );

            # Logically progress is 0 entering the 'running' state, but because
            # of implementation details we're clamping it to the range 1-99
            # inclusive.
            is $db->test_progress( $testid1 ), 1, "Progress should be 1 entering the 'running' state.";

            is $db->test_progress( $testid1, 0 ), 1, "Setting progress to 0 should succeed, but actual clamped value is returned,";
            is $db->test_progress( $testid1 ),    1, "and it should persist at the clamped value.";
            is $db->test_progress( $testid1, 0 ), 1, "Setting the same progress again should succeed.";

            is $db->test_progress( $testid1, 2 ), 2, "Setting a higher progress should be allowed,";
            is $db->test_progress( $testid1 ),    2, "and it should persist at the new value.";
            is $db->test_progress( $testid1, 2 ), 2, "Setting the same progress again should succeed.";

            throws_ok { $db->test_progress( $testid1, 0 ) } qr/illegal update/, "Setting a lower progress should throw an exception,";
            is $db->test_progress( $testid1 ), 2, "and it should persist at the old value.";

            is $db->test_progress( $testid1, 100 ), 99, "Setting progress to 100 should succeed, but actual clamped value is returned,";
            is $db->test_progress( $testid1 ),      99, "and it should persist at the clamped value.";

            $db->store_results( $testid1, '{}' );

            throws_ok { $db->test_progress( $testid1, 100 ) } qr/illegal update/, "Setting progress should throw an exception in 'completed' state.";
        };

        subtest 'Testid reuse' => sub {
            my $testid1 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            is ref $testid1, '', 'create_new_test returns "testid" scalar';

            advance_time( 11 );
            my $testid2 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            is $testid2, $testid1, 'reuse is determined from start time (as opposed to creation time)';

            $db->claim_test( $testid1 );
            advance_time( 10 );

            my $testid3 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            is $testid3, $testid1, 'old testid is reused before it expires';

            advance_time( 1 );
            my $testid4 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            isnt $testid4, $testid1, 'a new testid is generated after the old one expires';
        };

        subtest 'Termination of timed out tests' => sub {
            my $testid2 = $db->create_new_test( "zone2.rpcapi.example", {}, 10 );
            my $testid3 = $db->create_new_test( "zone3.rpcapi.example", {}, 10 );

            # testid2 started 11 seconds ago, testid3 started 10 seconds ago
            $db->claim_test( $testid2 );
            advance_time( 1 );
            $db->claim_test( $testid3 );
            advance_time( 10 );

            $db->process_unfinished_tests( undef, 10 );

            is $db->test_progress( $testid3 ), 1,   'leave test alone AT its timeout';
            is $db->test_progress( $testid2 ), 100, 'terminate test AFTER its timeout';

            is count_cancellation_messages( $db->test_results( $testid3 ) ), 0, 'no cancellation message present AT timeout';
            is count_cancellation_messages( $db->test_results( $testid2 ) ), 1, 'one cancellation message present AFTER timeout';
        };

        subtest 'Termination of crashed tests' => sub {
            my $testid4 = $db->create_new_test( "zone4.rpcapi.example", {}, 10 );
            $db->claim_test( $testid4 );

            $db->process_dead_test( $testid4 );

            is $db->test_progress( $testid4 ), 100, 'terminates test';

            is count_died_messages( $db->test_results( $testid4 ) ), 1, 'one died message present after crash';
        };

        subtest 'Do not reuse batch tests' => sub {
            my %user = (
                username => "user",
                api_key  => "key"
            );
            my @domains = ( 'zone1.rpcapi.example', 'zone5.rpcapi.example' );
            my $params = {
                %user,
                domains => \@domains,
                test_params => {
                    priority => 5,
                    queue   => 0
                }
            };
            $db->add_api_user( $user{username}, $user{api_key} );
            my $batch_id = $db->add_batch_job( $params );

            my @batch_test_ids = $db->dbh->selectall_array(
                q[
                    SELECT hash_id
                    FROM test_results
                    WHERE batch_id = ?
                ],
                undef,
                $batch_id
            );
            @batch_test_ids = map { $$_[0] } @batch_test_ids;

            if ( @batch_test_ids != 2 ) {
                BAIL_OUT( 'There should be 2 tests in database for this batch_id' );
            }

            my ( $count_zone1 ) = $db->dbh->selectrow_array(
                q[
                    SELECT count(*)
                    FROM test_results
                    WHERE domain = 'zone1.rpcapi.example'
                ]
            );
            is( $count_zone1, 3, '3 tests for domain "zone1.rpcapi.example' );
            my $test_id = $db->create_new_test( 'zone5.rpcapi.example', {}, 10 );
            ok( ! grep(/$test_id/, @batch_test_ids), 'new single test should not reuse batch tests' );
        };
    };
};

for my $msg ( @{ $log->msgs } ) {
    my $text = sprintf( "%s: %s", $msg->{level}, $msg->{message} );
    if ( $msg->{level} =~ /trace|debug|info|notice/ ) {
        note $text;
    }
    else {
        diag $text;
    }
}

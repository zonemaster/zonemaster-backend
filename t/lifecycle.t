use strict;
use warnings;
use 5.14.2;

use Test::More tests => 2;
use Test::Exception;
use Test::NoWarnings;
use Log::Any::Test;
use Log::Any qw( $log );

my $TIME = CORE::time();
BEGIN {
    *CORE::GLOBAL::time = sub { $TIME };
}

use JSON::PP;
use File::ShareDir qw[dist_file];
use File::Temp qw[tempdir];

use Zonemaster::Engine;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;

sub advance_time {
    my ( $delta ) = @_;
    $TIME += $delta;
}

my $db_backend = Zonemaster::Backend::Config->check_db( $ENV{TARGET} || 'SQLite' );
diag "database: $db_backend";

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

[ZONEMASTER]
age_reuse_previous_test = 10
EOF

subtest 'Everything but Test::NoWarnings' => sub {
    lives_ok {    # Make sure we get to print log messages in case of errors.
        my $dbclass = Zonemaster::Backend::DB->get_db_class( $db_backend );
        my $db      = $dbclass->from_config( $config );

        if ( $db_backend eq 'SQLite' ) {
            $db->create_schema();
        }

        subtest 'Testid reuse' => sub {
            my $testid1 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            advance_time( 11 );
            my $testid2 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );

            $db->test_progress( $testid1, 1 );    # mark test as started
            advance_time( 10 );

            my $testid3 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );
            advance_time( 1 );
            my $testid4 = $db->create_new_test( "zone1.rpcapi.example", {}, 10 );

            is ref $testid1, '', 'start_domain_test returns "testid" scalar';
            is $testid2,   $testid1, 'reuse is determined from start time (as opposed to creation time)';
            is $testid3,   $testid1, 'old testid is reused before it expires';
            isnt $testid4, $testid1, 'a new testid is generated after the old one expires';
        };

        subtest 'Termination of timed out tests' => sub {
            my $testid2 = $db->create_new_test( "zone2.rpcapi.example", {}, 10 );
            my $testid3 = $db->create_new_test( "zone3.rpcapi.example", {}, 10 );

            # testid2 started 11 seconds ago, testid3 started 10 seconds ago
            $db->test_progress( $testid2, 1 );
            advance_time( 1 );
            $db->test_progress( $testid3, 1 );
            advance_time( 10 );

            $db->process_unfinished_tests( undef, 10 );

            is $db->test_progress( $testid3 ), 1,   'leave test alone AT its timeout';
            is $db->test_progress( $testid2 ), 100, 'terminate test AFTER its timeout';
        };

        subtest 'Termination of crashed tests' => sub {
            my $testid4 = $db->create_new_test( "zone4.rpcapi.example", {}, 10 );
            $db->test_progress( $testid4, 1 );    # mark test as started

            $db->process_dead_test( $testid4 );

            is $db->test_progress( $testid4 ), 100, 'terminates test';
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

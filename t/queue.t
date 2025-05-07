use strict;
use warnings;
use 5.14.2;

use Test::More tests => 2;
use Test::NoWarnings;
use Log::Any::Test;

use File::Basename        qw( dirname );
use File::Spec::Functions qw( rel2abs );
use File::Temp            qw( tempdir );
use Log::Any              qw( $log );
use Test::Differences;
use Test::Exception;
use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB qw( $TEST_RUNNING );
use Zonemaster::Engine;

my $t_path;
BEGIN {
    $t_path = dirname( rel2abs( $0 ) );
}
use lib $t_path;
use TestUtil;

my $db_backend = TestUtil::db_backend();
my $tempdir    = tempdir( CLEANUP => 1 );
my $config     = Zonemaster::Backend::Config->parse( <<EOF );
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

subtest 'Everything but Test::NoWarnings' => sub {
    lives_ok {    # Make sure we get to print log messages in case of errors.
        my $db = TestUtil::init_db( $config );

        subtest 'Claiming waiting tests for processing' => sub {
            eq_or_diff
              [ $db->get_test_request( undef ) ],
              [ undef, undef ],
              "An empty list is returned when queue is empty";

            my $testid1 = $db->create_new_test( "1.claim.test", {}, 10 );
            eq_or_diff
              [ $db->get_test_request( undef ) ],
              [ $testid1, undef ],
              "A waiting test is returned if one is available";
            eq_or_diff
              [ $db->get_test_request( undef ) ],
              [ undef, undef ],
              "Claimed test is removed from queue";
            is
              $db->test_state( $testid1 ),
              $TEST_RUNNING,
              "Claimed test is in 'running' state";
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

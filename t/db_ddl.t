use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;
use Test::NoWarnings qw(warnings clear_warnings);

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

my $dbclass = Zonemaster::Backend::DB->get_db_class( $db_backend );
my $db      = $dbclass->from_config( $config );


subtest 'Everything but Test::NoWarnings' => sub {

    subtest 'drop and create' => sub {
        subtest 'first drop (cleanup) ... ' => sub {
            $db->drop_tables();
            dies_ok {
                $db->dbh->do( 'SELECT 1 FROM test_results' )
            }
            'table "test_results" sould not exist';
        };
        subtest '... then drop after create ...' => sub {
            $db->create_schema();
            my ( $res ) = $db->dbh->selectrow_array( 'SELECT count(*) FROM test_results' );
            is $res, 0, 'a. after create, table "test_results" should exist and be empty';

            $db->drop_tables();
            dies_ok {
                $db->dbh->do( 'SELECT 1 FROM test_results' )
            }
            'b. after drop, table "test_results" sould be removed';
        };
    };

    subtest 'constraints' => sub {
        $db->create_schema();

        subtest 'constraint unique' => sub {
            my $time = $db->format_time( time() );
            my @constraints = (
                {
                    table => 'test_results',
                    key => 'hash_id',
                    sql => "INSERT INTO test_results (hash_id,domain,created_at,params)
                           VALUES ('0123456789abcdef', 'domain.test', '$time', '{}')"
                },
                {
                    table => 'log_level',
                    key => 'level',
                    sql => "INSERT INTO log_level (level, value) VALUES ('OTHER', 10)"
                },
                {
                    table => 'users',
                    key => 'username',
                    sql => "INSERT INTO users (username) VALUES ('user1')"
                },
            );

            for my $c (@constraints) {
                $db->dbh->do( $c->{sql} );
                throws_ok {
                    $db->dbh->do( $c->{sql} );
                }
                qr/(unique constraint|duplicate entry)/i, "$c->{table}($c->{key}) key should be unique";
            }
        };

        subtest 'constraint on foreign key' => sub {
            subtest 'result_entries - hash_id should exist in test_results(hash_id)' => sub {
                my $hash_id_ok = "0123456789abcdef";
                # INFO is 1
                my $sql = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args)
                           VALUES ('$hash_id_ok', 1, 'MODULE', 'TESTCASE', 'TAG', 42, '{}')";
                my $inserted_rows = $db->dbh->do( $sql );
                is $inserted_rows, 1, 'can insert an entry with an existing hash_id';

                throws_ok {
                    my $hash_id_ko = "aaaaaaaaaaaaaaaa";
                    my $sql = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args)
                        VALUES ('$hash_id_ko', 1, 'MODULE', 'TESTCASE', 'TAG', 42, '{}')";
                    $db->dbh->do( $sql );
                }
                qr/foreign key/i, 'cannot insert an entry with an non-existing hash_id';
            };

            subtest 'result_entries - level should exist in log_level(level)' => sub {
                my $level = 1; # INFO
                my $sql = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args)
                           VALUES ('0123456789abcdef', '$level', 'MODULE', 'TESTCASE', 'TAG', 42, '{}')";
                my $inserted_rows = $db->dbh->do( $sql );
                is $inserted_rows, 1, 'can insert an entry with an existing level';

                throws_ok {
                    my $level = 42; # does not exist
                    my $sql = "INSERT INTO result_entries (hash_id, level, module, testcase, tag, timestamp, args)
                        VALUES ('0123456789abcdef', '$level', 'MODULE', 'TESTCASE', 'TAG', 42, '{}')";
                    $db->dbh->do( $sql );
                }
                qr/foreign key/i, 'cannot insert an entry with an non-existing level';
            };
        };
    };
};

# FIXME: hack to avoid getting warnings from Test::NoWarnings
my @warn = warnings();
if ( @warn == 7 ) {
    clear_warnings();
}

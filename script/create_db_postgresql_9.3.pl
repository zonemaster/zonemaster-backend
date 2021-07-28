use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::PostgreSQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'PostgreSQL' ) {
    die "The configuration file does not contain the MySQL backend";
}
my $dbh     = Zonemaster::Backend::DB::PostgreSQL->from_config( $config )->dbh;
my $db_user = $config->POSTGRESQL_user;

sub create_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS test_results CASCADE' );

    $dbh->do(
        'CREATE TABLE test_results (
                id serial PRIMARY KEY,
                hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL,
                batch_id integer,
                creation_time timestamp without time zone DEFAULT NOW() NOT NULL,
                test_start_time timestamp without time zone,
                test_end_time timestamp without time zone,
                priority integer DEFAULT 10,
                queue integer DEFAULT 0,
                progress integer DEFAULT 0,
                params_deterministic_hash varchar(32),
                params json NOT NULL,
                undelegated integer NOT NULL DEFAULT 0,
                results json,
                nb_retries integer NOT NULL DEFAULT 0
            )
        '
    );

    $dbh->do(
        'CREATE INDEX test_results__hash_id ON test_results (hash_id)'
    );
    $dbh->do(
        'CREATE INDEX test_results__params_deterministic_hash ON test_results (params_deterministic_hash)'
    );
    $dbh->do(
        'CREATE INDEX test_results__batch_id_progress ON test_results (batch_id, progress)'
    );
    $dbh->do(
        'CREATE INDEX test_results__progress ON test_results (progress)'
    );
    $dbh->do(
        "CREATE INDEX test_results__domain_undelegated ON test_results ((params->>'domain'), (params->>'undelegated'))"
    );


    $dbh->do( "ALTER TABLE test_results OWNER TO $db_user" );


    ####################################################################
    # BATCH JOBS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS batch_jobs CASCADE' );

    $dbh->do(
        'CREATE TABLE batch_jobs (
                id serial PRIMARY KEY,
                username varchar(50) NOT NULL,
                creation_time timestamp without time zone DEFAULT NOW() NOT NULL
            )
        '
    );

    $dbh->do( "ALTER TABLE batch_jobs OWNER TO $db_user" );


    ####################################################################
    # USERS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS users CASCADE' );

    $dbh->do(
        'CREATE TABLE users (
                id serial PRIMARY KEY,
                user_info json
            )
        '
    );

    $dbh->do( "ALTER TABLE users OWNER TO $db_user" );

}

create_db();

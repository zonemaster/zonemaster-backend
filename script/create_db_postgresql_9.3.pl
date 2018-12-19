use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;

die "The configuration file does not contain the PostgreSQL backend" unless (lc(Zonemaster::Backend::Config->load_config()->BackendDBType()) eq 'postgresql');
my $db_user = Zonemaster::Backend::Config->load_config()->DB_user();
my $db_password = Zonemaster::Backend::Config->load_config()->DB_password();
my $connection_string = Zonemaster::Backend::Config->load_config()->DB_connection_string();

my $dbh = DBI->connect( $connection_string, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 } );

sub create_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS test_specs CASCADE' );
    $dbh->do( 'DROP SEQUENCE IF EXISTS test_specs_id_seq' );

    $dbh->do( 'DROP TABLE IF EXISTS test_results CASCADE' );
    $dbh->do( 'DROP SEQUENCE IF EXISTS test_results_id_seq' );

    $dbh->do(
        'CREATE SEQUENCE test_results_id_seq
                                        INCREMENT BY 1
                                        NO MAXVALUE
                                        NO MINVALUE
                                        CACHE 1
        '
    );

    $dbh->do( "ALTER TABLE public.test_results_id_seq OWNER TO $db_user" );

    $dbh->do(
        'CREATE TABLE test_results (
                        id integer DEFAULT nextval(\'test_results_id_seq\'::regclass) primary key,
                        hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL,
                        batch_id integer DEFAULT NULL,
                        creation_time timestamp without time zone DEFAULT NOW() NOT NULL,
                        test_start_time timestamp without time zone DEFAULT NULL,
                        test_end_time timestamp without time zone DEFAULT NULL,
                        priority integer DEFAULT 10,
                        queue integer DEFAULT 0,
                        progress integer DEFAULT 0,
                        params_deterministic_hash character varying(32),
                        params json NOT NULL,
                        results json DEFAULT NULL
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
    
    $dbh->do( "CREATE INDEX test_results__domain_undelegated ON test_results ((params->>'domain'), (params->>'undelegated'))" );

    
    $dbh->do( "ALTER TABLE test_results OWNER TO $db_user" );

    ####################################################################
    # BATCH JOBS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS batch_jobs CASCADE' );
    $dbh->do( 'DROP SEQUENCE IF EXISTS batch_jobs_id_seq' );

    $dbh->do(
        'CREATE SEQUENCE batch_jobs_id_seq
                                        INCREMENT BY 1
                                        NO MAXVALUE
                                        NO MINVALUE
                                        CACHE 1
        '
    );

    $dbh->do( "ALTER TABLE public.batch_jobs_id_seq OWNER TO $db_user" );

    $dbh->do(
        'CREATE TABLE batch_jobs (
                        id integer DEFAULT nextval(\'batch_jobs_id_seq\'::regclass) primary key,
                        username character varying(50) NOT NULL,
                        creation_time timestamp without time zone DEFAULT NOW() NOT NULL
                )
        '
    );
    $dbh->do( "ALTER TABLE batch_jobs OWNER TO $db_user" );

    ####################################################################
    # USERS
    ####################################################################
    $dbh->do( 'DROP TABLE IF EXISTS users CASCADE' );
    $dbh->do( 'DROP SEQUENCE IF EXISTS users_id_seq' );

    $dbh->do(
        'CREATE SEQUENCE users_id_seq
                                        INCREMENT BY 1
                                        NO MAXVALUE
                                        NO MINVALUE
                                        CACHE 1
        '
    );

    $dbh->do( "ALTER TABLE public.users_id_seq OWNER TO $db_user" );

    $dbh->do(
        'CREATE TABLE users (
                        id integer DEFAULT nextval(\'users_id_seq\'::regclass) primary key,
                        user_info json DEFAULT NULL
                )
        '
    );
    $dbh->do( "ALTER TABLE users OWNER TO $db_user" );

}

create_db();

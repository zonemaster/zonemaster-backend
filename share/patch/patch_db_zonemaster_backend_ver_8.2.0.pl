use strict;
use warnings;

use Try::Tiny;

use Zonemaster::Backend::Config;

my $config = Zonemaster::Backend::Config->load_config();

my %patch = (
    mysql       => \&patch_db_mysql,
    postgresql  => \&patch_db_postgresql,
    sqlite      => \&patch_db_sqlite,
);

my $db_engine = $config->DB_engine;

if ( $db_engine =~ /^(MySQL|PostgreSQL|SQLite)$/ ) {
    $patch{ lc $db_engine }();
}
else {
    die "Unknown database engine configured: $db_engine\n";
}

sub patch_db_mysql {
    use Zonemaster::Backend::DB::MySQL;

    my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        # update columns names, data type and default value
        $dbh->do( 'ALTER TABLE test_results CHANGE COLUMN creation_time created_at DATETIME NOT NULL' );
        $dbh->do( 'ALTER TABLE test_results CHANGE COLUMN test_start_time started_at DATETIME DEFAULT NULL' );
        $dbh->do( 'ALTER TABLE test_results CHANGE COLUMN test_end_time ended_at DATETIME DEFAULT NULL' );

        $dbh->do( 'ALTER TABLE batch_jobs CHANGE COLUMN creation_time created_at DATETIME DEFAULT NULL' );

        # add table constraints
        $dbh->do( 'ALTER TABLE test_results ADD CONSTRAINT UNIQUE (hash_id)' );
        $dbh->do( 'ALTER TABLE users ADD CONSTRAINT UNIQUE (username)' );

        $dbh->commit();
    } catch {
        print( "Could not upgrade database:  " . $_ );

        eval { $dbh->rollback() };
    };
}

sub patch_db_postgresql {
    use Zonemaster::Backend::DB::PostgreSQL;

    my $db = Zonemaster::Backend::DB::PostgreSQL->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    try {
        # remove default value for "creation_time"
        $dbh->do( 'ALTER TABLE test_results ALTER COLUMN creation_time DROP DEFAULT' );
        $dbh->do( 'ALTER TABLE batch_jobs ALTER COLUMN creation_time DROP DEFAULT' );

        # rename columns
        $dbh->do( 'ALTER TABLE test_results RENAME COLUMN creation_time TO created_at' );
        $dbh->do( 'ALTER TABLE test_results RENAME COLUMN test_start_time TO started_at' );
        $dbh->do( 'ALTER TABLE test_results RENAME COLUMN test_end_time TO ended_at' );
        $dbh->do( 'ALTER TABLE batch_jobs RENAME COLUMN creation_time TO created_at' );

        # add table constraints
        $dbh->do( 'ALTER TABLE test_results ADD UNIQUE (hash_id)' );
        $dbh->do( 'ALTER TABLE users ADD UNIQUE (username)' );

        $dbh->commit();
    } catch {
        print( "Could not upgrade database:  " . $_ );

        eval { $dbh->rollback() };
    };
}

sub patch_db_sqlite {
    use Zonemaster::Backend::DB::SQLite;

    my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );
    my $dbh = $db->dbh;

    $dbh->{AutoCommit} = 0;

    # since we change the default value for a column, the whole table needs to
    # be recreated
    #  1. rename the table to "<table>_old"
    #  2. recreate a clean table schema
    #  3. populate it with the values from "<table>_old"
    #  4. remove "<table>_old" and indexes
    #  5. recreate the indexes
    try {
        $dbh->do('ALTER TABLE test_results RENAME TO test_results_old');
        $dbh->do('ALTER TABLE batch_jobs RENAME TO batch_jobs_old');
        $dbh->do('ALTER TABLE users RENAME TO users_old');

        # create the tables
        $db->create_schema();

        # populate the tables
        $dbh->do('
            INSERT INTO test_results
            (
                id,
                hash_id,
                domain,
                batch_id,
                created_at,
                started_at,
                ended_at,
                priority,
                queue,
                progress,
                fingerprint,
                params,
                results,
                undelegated
            )
            SELECT
                id,
                hash_id,
                domain,
                batch_id,
                creation_time,
                test_start_time,
                test_end_time,
                priority,
                queue,
                progress,
                fingerprint,
                params,
                results,
                undelegated
            FROM test_results_old
        ');

        $dbh->do('
            INSERT INTO batch_jobs
            (
                id,
                username,
                created_at
            )
            SELECT
                id,
                username,
                creation_time
            FROM batch_jobs_old
        ');

        $dbh->do('
            INSERT INTO users
            (
                id,
                username,
                api_key
            )
            SELECT
                id,
                username,
                api_key
            FROM users_old
        ');

        # delete old tables
        $dbh->do('DROP TABLE test_results_old');
        $dbh->do('DROP TABLE batch_jobs_old');
        $dbh->do('DROP TABLE users_old');

        # recreate indexes
        $db->create_schema();

        $dbh->commit();
    } catch {
        print( "Error while upgrading database:  " . $_ );

        eval { $dbh->rollback() };
    };
}
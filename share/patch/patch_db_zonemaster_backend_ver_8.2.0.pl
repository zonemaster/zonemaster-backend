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
        # update columns data type from TIMESTAMP to DATETIME and default
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN creation_time DATETIME NOT NULL' );
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN test_start_time DATETIME DEFAULT NULL' );
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN test_end_time DATETIME DEFAULT NULL' );

        $dbh->do( 'ALTER TABLE batch_jobs MODIFY COLUMN creation_time DATETIME DEFAULT NULL' );

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

        # create the tables
        $db->create_schema();

        # populate the tables
        $dbh->do('
            INSERT INTO test_results
            SELECT * FROM test_results_old
        ');
        $dbh->do('
            INSERT INTO batch_jobs
            SELECT * FROM batch_jobs_old
        ');

        # delete old tables
        $dbh->do('DROP TABLE test_results_old');
        $dbh->do('DROP TABLE batch_jobs_old');

        # recreate indexes
        $db->create_schema();

        $dbh->commit();
    } catch {
        print( "Error while upgrading database:  " . $_ );

        eval { $dbh->rollback() };
    };
}

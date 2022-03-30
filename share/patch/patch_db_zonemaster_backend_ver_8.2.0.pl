use strict;
use warnings;

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

    # update columns data type from TIMESTAMP to DATETIME and default
    eval {
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN creation_time DATETIME NOT NULL' );
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN test_start_time DATETIME DEFAULT NULL' );
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN test_end_time DATETIME DEFAULT NULL' );

        $dbh->do( 'ALTER TABLE batch_jobs MODIFY COLUMN creation_time DATETIME DEFAULT NULL' );
    };
    print( "Could not update column data type:  " . $@ ) if ($@);
}

sub patch_db_postgresql {
    use Zonemaster::Backend::DB::PostgreSQL;

    my $db = Zonemaster::Backend::DB::PostgreSQL->from_config( $config );
    my $dbh = $db->dbh;

    # remove default value for "creation_time"
    eval {
        $dbh->do( 'ALTER TABLE test_results ALTER COLUMN creation_time DROP DEFAULT' );
        $dbh->do( 'ALTER TABLE batch_jobs ALTER COLUMN creation_time DROP DEFAULT' );
    };
    print( "Error while droping column default:  " . $@ ) if ($@);

    # change "creation_time" type from TIMESTAMP to DATETIME
    eval {
        $dbh->do( 'ALTER TABLE test_results ALTER COLUMN creation_time SET DATE TYPE TIMESTAMP' );
        $dbh->do( 'ALTER TABLE batch_jobs ALTER COLUMN creation_time SET DATE TYPE TIMESTAMP' );
    };
    print( "Could not update column data type:  " . $@ ) if ($@);
}

sub patch_db_sqlite {
    use Zonemaster::Backend::DB::SQLite;

    my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );
    my $dbh = $db->dbh;

    # since we change the default value for a column, the whole table needs to
    # be recreated
    #  1. rename the "test_results" table to "test_results_old"
    #  2. create the new "test_results" table
    #  3. populate it with the values from "test_results_old"
    #  4. remove old table and indexes
    #  5. recreate the indexes
    eval {
        $dbh->do('ALTER TABLE test_results RENAME TO test_results_old');

        # create the table
        $db->create_schema();

        # populate it
        $dbh->do('
            INSERT INTO test_results
            SELECT * FROM test_results_old
        ');

        $dbh->do('DROP TABLE test_results_old');

        # recreate indexes
        $db->create_schema();
    };
    print( "Error while updating the 'test_results' table schema:  " . $@ ) if ($@);

    eval {
        $dbh->do('ALTER TABLE batch_jobs RENAME TO batch_jobs_old');

        # create the table
        $db->create_schema();

        # populate it
        $dbh->do('
            INSERT INTO batch_jobs
            SELECT * FROM batch_jobs_old
        ');

        $dbh->do('DROP TABLE batch_jobs_old');

        # recreate indexes
        $db->create_schema();
    };
    print( "Error while updating the 'batch_jobs' table schema:  " . $@ ) if ($@);
}

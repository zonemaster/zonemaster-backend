use strict;
use warnings;
use JSON::PP;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::MySQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'MySQL' ) {
    die "The configuration file does not contain the MySQL backend";
}
my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
my $dbh = $db->dbh;


sub patch_db {
    # Remove the trigger
    $dbh->do( 'DROP TRIGGER IF EXISTS before_insert_test_results' );

    # Set the "hash_id" field to NOT NULL
    eval {
        $dbh->do( 'ALTER TABLE test_results MODIFY COLUMN hash_id VARCHAR(16) NOT NULL' );
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

    # Rename column "params_deterministic_hash" into "fingerprint"
    # Since MariaDB 10.5.2 (2020-03-26) <https://mariadb.com/kb/en/mariadb-1052-release-notes/>
    #   ALTER TABLE t1 RENAME COLUMN old_col TO new_col;
    # Before that we need to use CHANGE COLUMN <https://mariadb.com/kb/en/alter-table/#change-column>
    eval {
        $dbh->do('ALTER TABLE test_results CHANGE COLUMN params_deterministic_hash fingerprint CHARACTER VARYING(32)');
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

    # Update index
    eval {
        # retrieve all indexes by key name
        my $indexes = $dbh->selectall_hashref( 'SHOW INDEXES FROM test_results', 'Key_name' );
        if ( exists($indexes->{test_results__params_deterministic_hash}) ) {
            $dbh->do( "DROP INDEX test_results__params_deterministic_hash ON test_results" );
        }
        $dbh->do( "CREATE INDEX test_results__fingerprint ON test_results (fingerprint)" );
    };
    print( "Error while updating the index:  " . $@ ) if ($@);

    # Update the "undelegated" column
    my $sth1 = $dbh->prepare('SELECT id, params from test_results', undef);
    $sth1->execute;
    while ( my $row = $sth1->fetchrow_hashref ) {
        my $id = $row->{id};
        my $raw_params = _decode_json_sanitize($row->{params});
        my $ds_info_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{ds_info}};
        my $nameservers_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{nameservers}};
        my $undelegated = $ds_info_values > 0 || $nameservers_values > 0 || 0;

        $dbh->do('UPDATE test_results SET undelegated = ? where id = ?', undef, $undelegated, $id);
    }


    # remove the "user_info" column from the "users" table
    # the IF EXISTS clause is available with MariaDB but not MySQL
    eval {
        $dbh->do( "ALTER TABLE users DROP COLUMN user_info" );
    };
    print( "Error while dropping the column:  " . $@ ) if ($@);

    # remove the "nb_retries" column from the "test_results" table
    eval {
        $dbh->do( "ALTER TABLE test_results DROP COLUMN nb_retries" );
    };
    print( "Error while dropping the column:  " . $@ ) if ($@);
}

patch_db();

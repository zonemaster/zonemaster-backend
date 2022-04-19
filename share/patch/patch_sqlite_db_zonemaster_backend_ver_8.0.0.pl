use strict;
use warnings;
use JSON::PP;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::SQLite;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'SQLite' ) {
    die "The configuration file does not contain the SQLite backend";
}
my $db = Zonemaster::Backend::DB::SQLite->from_config( $config );
my $dbh = $db->dbh;


sub patch_db {

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
        # - nb_retries is omitted as we remove this column
        # - params_deterministic_hash is renamed to fingerprint
        $dbh->do('
            INSERT INTO test_results
            SELECT id,
                   hash_id,
                   domain,
                   batch_id,
                   creation_time,
                   test_start_time,
                   test_end_time,
                   priority,
                   queue,
                   progress,
                   params_deterministic_hash,
                   params,
                   results,
                   undelegated
            FROM test_results_old
        ');

        $dbh->do('DROP TABLE test_results_old');

        # recreate indexes
        $db->create_schema();
    };
    print( "Error while updating the 'test_results' table schema:  " . $@ ) if ($@);

    # Update the "undelegated" column
    my $sth1 = $dbh->prepare('SELECT id, params from test_results', undef);
    $sth1->execute;
    while ( my $row = $sth1->fetchrow_hashref ) {
        my $id = $row->{id};
        my $raw_params = decode_json($row->{params});
        my $ds_info_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{ds_info}};
        my $nameservers_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{nameservers}};
        my $undelegated = $ds_info_values > 0 || $nameservers_values > 0 || 0;

        $dbh->do('UPDATE test_results SET undelegated = ? where id = ?', undef, $undelegated, $id);
    }


    # in order to properly drop a column, the whole table needs to be recreated
    #  1. rename the "users" table to "users_old"
    #  2. create the new "users" table
    #  3. populate it with the values from "users_old"
    #  4. remove old table
    eval {
        $dbh->do('ALTER TABLE users RENAME TO users_old');

        # create the table
        $db->create_schema();

        # populate it
        $dbh->do('INSERT INTO users SELECT id, username, api_key FROM users_old');

        $dbh->do('DROP TABLE users_old');
    };
    print( "Error while updating the 'users' table schema:  " . $@ ) if ($@);
}

patch_db();

use strict;
use warnings;
use JSON::PP;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::PostgreSQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'PostgreSQL' ) {
    die "The configuration file does not contain the PostgreSQL backend";
}
my $db = Zonemaster::Backend::DB::PostgreSQL->from_config( $config );
my $dbh = $db->dbh;


sub patch_db {
    # Drop default value for the "hash_id" field
    $dbh->do( 'ALTER TABLE test_results ALTER COLUMN hash_id DROP DEFAULT' );

    # Rename column "params_deterministic_hash" into "fingerprint"
    eval {
        $dbh->do( 'ALTER TABLE test_results RENAME COLUMN params_deterministic_hash TO fingerprint' );
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

    # Update index
    eval {
        # clause IF EXISTS available since PostgreSQL >= 9.2
        $dbh->do( "DROP INDEX IF EXISTS test_results__params_deterministic_hash" );
        $dbh->do( "CREATE INDEX test_results__fingerprint ON test_results (fingerprint)" );
    };
    print( "Error while updating the index:  " . $@ ) if ($@);

    # test_start_time and test_end_time default to NULL
    eval {
        $dbh->do('ALTER TABLE test_results ALTER COLUMN test_start_time SET DEFAULT NULL');
        $dbh->do('ALTER TABLE test_results ALTER COLUMN test_end_time SET DEFAULT NULL');
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);


    # Add missing "domain" and "undelegated" columns
    eval {
        $dbh->do( "ALTER TABLE test_results ADD COLUMN domain VARCHAR(255) NOT NULL DEFAULT ''" );
        $dbh->do( 'ALTER TABLE test_results ADD COLUMN undelegated integer NOT NULL DEFAULT 0' );
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

    # Update index
    eval {
        # clause IF EXISTS available since PostgreSQL >= 9.2
        $dbh->do( "DROP INDEX IF EXISTS test_results__domain_undelegated" );
        $dbh->do( "CREATE INDEX test_results__domain_undelegated ON test_results (domain, undelegated)" );
    };
    print( "Error while updating the index:  " . $@ ) if ($@);

    # New index
    eval {
        # clause IF NOT EXISTS available since PostgreSQL >= 9.5
        $dbh->do( 'CREATE INDEX IF NOT EXISTS test_results__progress_priority_id ON test_results (progress, priority DESC, id) WHERE (progress = 0)' );
    };
    print( "Error while creating the index:  " . $@ ) if ($@);

    # Update the "domain" column
    $dbh->do( "UPDATE test_results SET domain = (params->>'domain')" );
    # remove default value to "domain" column
    $dbh->do( "ALTER TABLE test_results ALTER COLUMN domain DROP DEFAULT" );

    # Update the "undelegated" column
    my $sth1 = $dbh->prepare('SELECT id, params from test_results', undef);
    $sth1->execute;
    while ( my $row = $sth1->fetchrow_hashref ) {
        my $id = $row->{id};
        my $raw_params;

        if (utf8::is_utf8($row->{params}) ) {
            $raw_params = decode_json( encode_utf8 ( $row->{params} ) );
        } else {
            $raw_params = decode_json( $row->{params} );
        }

        my $ds_info_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{ds_info}};
        my $nameservers_values = scalar grep !/^$/, map { values %$_ } @{$raw_params->{nameservers}};
        my $undelegated = $ds_info_values > 0 || $nameservers_values > 0 || 0;

        $dbh->do('UPDATE test_results SET undelegated = ? where id = ?', undef, $undelegated, $id);
    }

    # add "username" and "api_key" columns to the "users" table
    eval {
        $dbh->do( 'ALTER TABLE users ADD COLUMN username VARCHAR(128)' );
        $dbh->do( 'ALTER TABLE users ADD COLUMN api_key VARCHAR(512)' );
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

    # update the columns
    $dbh->do( "UPDATE users SET username = (user_info->>'username'), api_key = (user_info->>'api_key')" );

    # remove the "user_info" column from the "users" table
    $dbh->do( "ALTER TABLE users DROP COLUMN IF EXISTS user_info" );
}

patch_db();

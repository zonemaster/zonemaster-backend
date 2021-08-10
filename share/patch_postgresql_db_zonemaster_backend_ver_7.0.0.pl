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

    # Add missing "undelegated" column
    eval {
        $dbh->do( 'ALTER TABLE test_results ADD COLUMN undelegated integer NOT NULL DEFAULT 0' );
    };
    print( "Error while changing DB schema:  " . $@ ) if ($@);

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
}

patch_db();

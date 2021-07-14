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
    die "The configuration file does not contain the PostgreSQL backend";
}
my $dbh = Zonemaster::Backend::DB::PostgreSQL->from_config( $config )->dbh;

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'ALTER TABLE test_results ADD COLUMN undelegated integer NOT NULL DEFAULT 0' );
}

patch_db();


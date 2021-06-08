use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::MySQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'MySQL' ) {
    die "The configuration file does not contain the MySQL backend";
}
my $dbh = Zonemaster::Backend::DB::MySQL->from_config( $config )->dbh;

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'ALTER TABLE test_results ADD COLUMN hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL' );
}

patch_db();

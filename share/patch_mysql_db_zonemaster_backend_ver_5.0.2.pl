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
    ############################################################################
    # Convert column "results" to MEDIUMBLOB so that it can hold larger results
    ############################################################################
    $dbh->do( 'ALTER TABLE test_results MODIFY results mediumblob' );
}

patch_db();

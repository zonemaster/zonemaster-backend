use strict;
use warnings;

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::MySQL;

my $config = Zonemaster::Backend::Config->load_config();
if ( $config->DB_engine ne 'MySQL' ) {
    die "The configuration file does not contain the MySQL backend";
}
my $db = Zonemaster::Backend::DB::MySQL->from_config( $config );
$db->create_db();

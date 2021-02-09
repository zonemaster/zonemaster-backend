use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB::SQLite;

die "The configuration file does not contain the SQLite backend" unless (lc(Zonemaster::Backend::Config->load_config()->BackendDBType()) eq 'sqlite');
my $db_user = Zonemaster::Backend::Config->load_config()->DB_user();
my $db_password = Zonemaster::Backend::Config->load_config()->DB_password();
my $connection_string = Zonemaster::Backend::Config->load_config()->DB_connection_string();

my $config = Zonemaster::Backend::Config->load_config();

my $db = Zonemaster::Backend::DB::SQLite->new( { config => $config } );
$db->create_db();

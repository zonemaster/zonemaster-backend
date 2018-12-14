use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;

die "The configuration file does not contain the MySQL backend" unless (lc(Zonemaster::Backend::Config->new()->BackendDBType()) eq 'mysql');
my $db_user = Zonemaster::Backend::Config->new()->DB_user();
my $db_password = Zonemaster::Backend::Config->new()->DB_password();
my $db_name = Zonemaster::Backend::Config->new()->DB_name();
my $connection_string = Zonemaster::Backend::Config->new()->DB_connection_string();

my $dbh = DBI->connect( $connection_string, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 } );

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'ALTER TABLE test_results ADD COLUMN hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL' );
}

patch_db();

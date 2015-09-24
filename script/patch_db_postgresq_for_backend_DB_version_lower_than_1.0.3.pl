use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::WebBackend::Config;

die "The configuration file does not contain the MySQL backend" unless (lc(Zonemaster::WebBackend::Config->BackendDBType()) eq 'mysql');
my $db_user = Zonemaster::WebBackend::Config->DB_user();
my $db_password = Zonemaster::WebBackend::Config->DB_password();
my $db_name = Zonemaster::WebBackend::Config->DB_name();
my $connection_string = Zonemaster::WebBackend::Config->DB_connection_string();

my $dbh = DBI->connect( $connection_string, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 } );

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'ALTER TABLE test_results ADD COLUMN hash_id VARCHAR(16) DEFAULT substring(md5(random()::text || clock_timestamp()::text) from 1 for 16) NOT NULL' );
}

patch_db();

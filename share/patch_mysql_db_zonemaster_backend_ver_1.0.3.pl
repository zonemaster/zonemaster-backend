use strict;
use warnings;
use utf8;
use Data::Dumper;
use Encode;

use DBI qw(:utils);

use Zonemaster::Backend::Config;

die "The configuration file does not contain the MySQL backend" unless (lc(Zonemaster::Backend::Config->load_config()->BackendDBType()) eq 'mysql');
my $db_user = Zonemaster::Backend::Config->load_config()->DB_user();
my $db_password = Zonemaster::Backend::Config->load_config()->DB_password();
my $db_name = Zonemaster::Backend::Config->load_config()->DB_name();
my $connection_string = Zonemaster::Backend::Config->load_config()->DB_connection_string();

my $dbh = DBI->connect( $connection_string, $db_user, $db_password, { RaiseError => 1, AutoCommit => 1 } );

sub patch_db {

    ####################################################################
    # TEST RESULTS
    ####################################################################
    $dbh->do( 'ALTER TABLE test_results ADD COLUMN hash_id VARCHAR(16) NULL' );

    $dbh->do( 'UPDATE test_results SET hash_id = (SELECT SUBSTRING(MD5(CONCAT(RAND(), UUID())) from 1 for 16))' );

    $dbh->do( 'ALTER TABLE test_results MODIFY hash_id VARCHAR(16) DEFAULT NULL NOT NULL' );
    
    $dbh->do(
		'CREATE TRIGGER before_insert_test_results
			BEFORE INSERT ON test_results
			FOR EACH ROW
			BEGIN
				IF new.hash_id IS NULL OR new.hash_id=\'\'
				THEN
					SET new.hash_id = SUBSTRING(MD5(CONCAT(RAND(), UUID())) from 1 for 16);
				END IF;
			END;
		'
    );
}

patch_db();

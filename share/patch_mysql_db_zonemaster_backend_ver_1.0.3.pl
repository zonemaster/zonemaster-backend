use strict;
use warnings;

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

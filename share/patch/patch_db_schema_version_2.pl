use 5.14.2;
use strict;
use warnings;

use Readonly;
use Zonemaster::Backend::Config;

Readonly my $TARGET_SCHEMA_VERSION   => 2;
Readonly my $EXPECTED_SCHEMA_VERSION => $TARGET_SCHEMA_VERSION - 1;

my $config = Zonemaster::Backend::Config->load_config();
say "Configured database engine: ", $config->DB_engine;

my $db               = $config->new_DB();
my $detected_version = $db->get_schema_version();
say "Target database schema version: ",        $TARGET_SCHEMA_VERSION;
say "Expected pre-migration schema version: ", $EXPECTED_SCHEMA_VERSION;
say "Detected database schema version: ",      $detected_version;

if ( $detected_version eq $TARGET_SCHEMA_VERSION ) {
    say "Schema already at target version.";
    exit 0;
}
elsif ( $detected_version ne $EXPECTED_SCHEMA_VERSION ) {
    say "Schema version requirement not met!";
    exit 2;
}

say "Starting database migration";

my $dbh    = $db->dbh;
my $engine = $config->DB_engine;

my $success = eval {
    $dbh->begin_work;

    if ( $engine eq 'MySQL' || $engine eq 'PostgreSQL' ) {
        $dbh->do(
            'ALTER TABLE test_results ADD COLUMN state VARCHAR(20) NOT NULL DEFAULT \'waiting\''
        );
        $dbh->do(
            'ALTER TABLE test_results ADD CONSTRAINT test_results_state_check CHECK (state IN (\'waiting\', \'running\', \'completed\', \'cancelled\', \'crashed\'))'
        );
    }
    elsif ( $engine eq 'SQLite' ) {
        # SQLite supports adding a column with a CHECK constraint via ALTER TABLE.
        # (On SQLite < 3.37 the CHECK is not validated against pre-existing rows,
        # which is harmless here: the DEFAULT fills them with 'waiting'.)
        $dbh->do(
            'ALTER TABLE test_results ADD COLUMN state VARCHAR(20) NOT NULL DEFAULT \'waiting\' CHECK (state IN (\'waiting\', \'running\', \'completed\', \'cancelled\', \'crashed\'))'
        );
    }
    else {
        die "Unsupported database engine: $engine";
    }

    # Back-fill state for existing rows based on progress.
    $dbh->do( "UPDATE test_results SET state = 'completed' WHERE progress = 100" );
    $dbh->do( "UPDATE test_results SET state = 'running' WHERE progress > 0 AND progress < 100" );

    # Update schema version.
    $dbh->do( "UPDATE schema_version SET version = ? WHERE id = 1", {}, $TARGET_SCHEMA_VERSION );

    $dbh->commit;
    1;
};


if ( !$success ) {
    my $error = $@;
    eval { $dbh->rollback };
    my $msg = "Migration failed: $error";
    if ( $engine eq 'MySQL' ) {
        $msg .=
            "Note: MySQL does not support transactional DDL, so the database may be left partially "
          . "migrated (the changes above were not rolled back). Before re-running this script, "
          . "manually undo any changes that were already applied, e.g.: "
          . "ALTER TABLE test_results DROP CONSTRAINT test_results_state_check; "
          . "ALTER TABLE test_results DROP COLUMN state;\n";
    }
    die $msg;
}
else {
    say "Migration done";
}

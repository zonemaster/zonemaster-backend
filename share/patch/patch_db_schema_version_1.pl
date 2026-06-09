use 5.14.2;
use strict;
use warnings;

use Readonly;
use Zonemaster::Backend::Config;

Readonly my $TARGET_SCHEMA_VERSION   => 1;
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

$db->dbh->do(
    "CREATE TABLE IF NOT EXISTS schema_version (
        id INTEGER PRIMARY KEY,
        version INTEGER NOT NULL,
        CHECK (id = 1),
        CHECK (version >= 1)
    )"
);
$db->dbh->do( "INSERT INTO schema_version (id, version) VALUES (1, ?)", {}, $TARGET_SCHEMA_VERSION );

say "Migration done";

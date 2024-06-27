use strict;
use warnings;

use Zonemaster::Backend::Config;
use Zonemaster::Engine;

my $config = Zonemaster::Backend::Config->load_config();

my $db_engine = $config->DB_engine;
print "Configured database engine: $db_engine\n";

if ( $db_engine =~ /^(MySQL|PostgreSQL|SQLite)$/ ) {
    print( "Starting database migration\n" );

    _update_result_entries( $config->new_DB()->dbh() );

    print( "\nMigration done\n" );
}
else {
    die "Unknown database engine configured: $db_engine\n";
}


sub _update_result_entries {
    my ( $dbh ) = @_;

    $dbh->do(<<SQL) or die 'Migration failed';
        UPDATE result_entries
           SET module = 'Backend'
         WHERE upper(module) = 'BACKEND_TEST_AGENT';
SQL
}

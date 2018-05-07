package Zonemaster::Backend::Config;
our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

use Config::IniFiles;
use File::ShareDir qw[dist_file];

our $path;
if ($ENV{ZONEMASTER_BACKEND_CONFIG_FILE}) {
    $path = $ENV{ZONEMASTER_BACKEND_CONFIG_FILE};
}
elsif ( -e '/etc/zonemaster/backend_config.ini' ) {
    $path = '/etc/zonemaster/backend_config.ini';
}
else {
    $path = dist_file('Zonemaster-Backend', "backend_config.ini");
}


=head1 SUBROUTINES

=cut

sub _load_config {
    my $cfg = Config::IniFiles->new( -file => $path );
    die "UNABLE TO LOAD $path ERRORS:[".join('; ', @Config::IniFiles::errors)."] \n" unless ( $cfg );

    return $cfg;
}

sub BackendDBType {
    my $cfg = _load_config();

    my $result;

    if ( lc( $cfg->val( 'DB', 'engine' ) ) eq 'sqlite' ) {
        $result = 'SQLite';
    }
    elsif ( lc( $cfg->val( 'DB', 'engine' ) ) eq 'postgresql' ) {
        $result = 'PostgreSQL';
    }
    elsif ( lc( $cfg->val( 'DB', 'engine' ) ) eq 'mysql' ) {
        $result = 'MySQL';
    }

    return $result;
}

sub DB_user {
    my $cfg = _load_config();

    return $cfg->val( 'DB', 'user' );
}

sub DB_password {
    my $cfg = _load_config();

    return $cfg->val( 'DB', 'password' );
}

sub DB_name {
    my $cfg = _load_config();

    return $cfg->val( 'DB', 'database_name' );
}

sub DB_connection_string {
    my $cfg = _load_config();

    my $db_engine = $_[1] || $cfg->val( 'DB', 'engine' );

    my $result;

    if ( lc( $db_engine ) eq 'sqlite' ) {
        $result = sprintf('DBI:SQLite:dbname=%s', $cfg->val( 'DB', 'database_name' ));
    }
    elsif ( lc( $db_engine ) eq 'postgresql' ) {
        $result = sprintf('DBI:Pg:database=%s;host=%s', $cfg->val( 'DB', 'database_name' ), $cfg->val( 'DB', 'database_host' ));
    }
    elsif ( lc( $db_engine ) eq 'mysql' ) {
        $result = sprintf('DBI:mysql:database=%s;host=%s', $cfg->val( 'DB', 'database_name' ), $cfg->val( 'DB', 'database_host' ));
    }

    return $result;
}

sub LogDir {
    my $cfg = _load_config();

    return $cfg->val( 'LOG', 'log_dir' );
}

sub PerlIntereter {
    my $cfg = _load_config();

    return $cfg->val( 'PERL', 'interpreter' );
}

sub PollingInterval {
    my $cfg = _load_config();

    return $cfg->val( 'DB', 'polling_interval' );
}

sub MaxZonemasterExecutionTime {
    my $cfg = _load_config();

    return $cfg->val( 'ZONEMASTER', 'max_zonemaster_execution_time' );
}

sub NumberOfProcessesForFrontendTesting {
    my $cfg = _load_config();

    my $nb = $cfg->val( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' );
    $nb = $cfg->val( 'ZONEMASTER', 'number_of_processes_for_frontend_testing' ) unless ($nb);
    
    return $nb;
}

sub NumberOfProcessesForBatchTesting {
    my $cfg = _load_config();

    my $nb = $cfg->val( 'ZONEMASTER', 'number_of_professes_for_batch_testing' );
    $nb = $cfg->val( 'ZONEMASTER', 'number_of_processes_for_batch_testing' ) unless ($nb);
    
    return $nb;
}

sub Maxmind_ISP_DB_File {
    my $cfg = _load_config();

    return $cfg->val( 'GEOLOCATION', 'maxmind_isp_db_file' );
}

sub Maxmind_City_DB_File {
    my $cfg = _load_config();

    return $cfg->val( 'GEOLOCATION', 'maxmind_city_db_file' );
}

sub force_hash_id_use_in_API_starting_from_id {
    my $cfg = _load_config();

    my $val = $cfg->val( 'ZONEMASTER', 'force_hash_id_use_in_API_starting_from_id' );

    return ($val)?($val):(0);
}

sub CustomProfilesPath {
    my $cfg = _load_config();

    my $value  = $cfg->val( 'ZONEMASTER', 'cutom_profiles_path' );
    $value  = $cfg->val( 'ZONEMASTER', 'custom_profiles_path' ) unless ($value);
    return $value;
}

sub GetCustomConfigParameter {
	my ($slef, $section, $param_name) = @_;
	
    my $cfg = _load_config();

    return $cfg->val( $section, $param_name );
}

sub lock_on_queue {
    my $cfg = _load_config();

    my $val = $cfg->val( 'ZONEMASTER', 'lock_on_queue' );

    return $val;
}

=head2 new_DB

Create a new database adapter object according to configuration.

The adapter connects to the database before it is returned.

=head3 INPUT

The database adapter class is selected based on the return value
of L<Zonemaster::Backend::Config->BackendDBType()>. The database
adapter class constructor is called without arguments and is expected
to configure itself according to available global configuration.

=back

=head3 RETURNS

A configured L<Zonemaster::Backend::DB> object.

=head3 EXCEPTIONS

=over 4

=item Dies if no database engine type is defined in the configuration.

=item Dies if no adapter for the configured database engine can be loaded.

=item Dies if the adapter is unable to connect to the database.

=back

=cut

sub new_DB {
    # Get DB type from config
    my $dbtype = Zonemaster::Backend::Config->BackendDBType();
    if (!defined $dbtype) {
        die "Unrecognized DB.engine in backend config";
    }

    # Load and construct DB adapter
    my $dbclass = 'Zonemaster::Backend::DB::' . $dbtype;
    require( join( "/", split( /::/, $dbclass ) ) . ".pm" );
    $dbclass->import();
    my $db = $dbclass->new;

    # Connect or die
    $db->dbh;

    return $db;
}

1;

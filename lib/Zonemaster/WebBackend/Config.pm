package Zonemaster::WebBackend::Config;
our $VERSION = '1.0.2';

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
    $path = dist_file('Zonemaster-WebBackend', "backend_config.ini");
}


sub _load_config {
    my $cfg = Config::IniFiles->new( -file => $path );
    die "UNABLE TO LOAD $path\n" unless ( $cfg );

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

sub NumberOfProfessesForFrontendTesting {
    my $cfg = _load_config();

    return $cfg->val( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' );
}

sub NumberOfProfessesForBatchTesting {
    my $cfg = _load_config();

    return $cfg->val( 'ZONEMASTER', 'number_of_professes_for_batch_testing' );
}

sub Maxmind_ISP_DB_File {
    my $cfg = _load_config();

    return $cfg->val( 'GEOLOCATION', 'maxmind_isp_db_file' );
}

sub Maxmind_City_DB_File {
    my $cfg = _load_config();

    return $cfg->val( 'GEOLOCATION', 'maxmind_city_db_file' );
}

1;

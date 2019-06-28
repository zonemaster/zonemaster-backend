package Zonemaster::Backend::Config;
our $VERSION = '1.1.0';

use strict;
use warnings;
use 5.14.2;

use Config;
use Config::IniFiles;
use File::ShareDir qw[dist_file];
use Log::Any qw( $log );
use Readonly;

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

Readonly my @SIG_NAME => split ' ', $Config{sig_name};

=head1 SUBROUTINES

=cut

sub load_config {
    my ( $class, $params ) = @_;
    my $self = {};

    $log->notice( "Loading config: $path" );
    
    $self->{cfg} = Config::IniFiles->new( -file => $path );
    die "UNABLE TO LOAD $path ERRORS:[".join('; ', @Config::IniFiles::errors)."] \n" unless ( $self->{cfg} );
    bless( $self, $class );
    return $self;
}

sub BackendDBType {
    my ($self) = @_;

    my $engine = $self->{cfg}->val( 'DB', 'engine' );
    if ( lc $engine eq 'sqlite' ) {
        return 'SQLite';
    }
    elsif ( lc $engine eq 'postgresql' ) {
        return 'PostgreSQL';
    }
    elsif ( lc $engine eq 'mysql' ) {
        return 'MySQL';
    }
    else {
        die "Unknown config value DB.engine: $engine\n";
    }
}

sub DB_user {
    my ($self) = @_;

    return $self->{cfg}->val( 'DB', 'user' );
}

sub DB_password {
    my ($self) = @_;

    return $self->{cfg}->val( 'DB', 'password' );
}

sub DB_name {
    my ($self) = @_;

    return $self->{cfg}->val( 'DB', 'database_name' );
}

sub DB_connection_string {
    my ($self) = @_;

    my $db_engine = $_[1] || $self->{cfg}->val( 'DB', 'engine' );

    my $result;

    if ( lc( $db_engine ) eq 'sqlite' ) {
        $result = sprintf('DBI:SQLite:dbname=%s', $self->{cfg}->val( 'DB', 'database_name' ));
    }
    elsif ( lc( $db_engine ) eq 'postgresql' ) {
        $result = sprintf('DBI:Pg:database=%s;host=%s', $self->{cfg}->val( 'DB', 'database_name' ), $self->{cfg}->val( 'DB', 'database_host' ));
    }
    elsif ( lc( $db_engine ) eq 'mysql' ) {
        $result = sprintf('DBI:mysql:database=%s;host=%s', $self->{cfg}->val( 'DB', 'database_name' ), $self->{cfg}->val( 'DB', 'database_host' ));
    }

    return $result;
}

sub LogDir {
    my ($self) = @_;

    return $self->{cfg}->val( 'LOG', 'log_dir' );
}

sub PerlInterpreter {
    my ($self) = @_;

    return $self->{cfg}->val( 'PERL', 'interpreter' );
}

sub PollingInterval {
    my ($self) = @_;

    return $self->{cfg}->val( 'DB', 'polling_interval' );
}

sub MaxZonemasterExecutionTime {
    my ($self) = @_;

    return $self->{cfg}->val( 'ZONEMASTER', 'max_zonemaster_execution_time' );
}

sub NumberOfProcessesForFrontendTesting {
    my ($self) = @_;

    my $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' );
    $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_processes_for_frontend_testing' ) unless ($nb);
    
    return $nb;
}

sub NumberOfProcessesForBatchTesting {
    my ($self) = @_;

    my $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_professes_for_batch_testing' );
    $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_processes_for_batch_testing' ) unless ($nb);
    
    return $nb;
}

sub force_hash_id_use_in_API_starting_from_id {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'force_hash_id_use_in_API_starting_from_id' );

    return ($val)?($val):(0);
}

sub ReadProfilesInfo {
    my ($self) = @_;
    
    my $profiles;
    $profiles->{'default'}->{type} = 'public';
    $profiles->{'default'}->{profile_file_name} = '';
    foreach my $public_profile ($self->{cfg}->Parameters('PUBLIC PROFILES')) {
        $profiles->{lc($public_profile)}->{type} = 'public';
        $profiles->{lc($public_profile)}->{profile_file_name} = $self->{cfg}->val('PUBLIC PROFILES', $public_profile);
    }

    foreach my $private_profile ($self->{cfg}->Parameters('PRIVATE PROFILES')) {
        $profiles->{lc($private_profile)}->{type} = 'private';
        $profiles->{lc($private_profile)}->{profile_file_name} = $self->{cfg}->val('PRIVATE PROFILES', $private_profile);
    }
    
    return $profiles;
}

sub ListPublicProfiles {
    my ($self) = @_;
    
    my $profiles;
    $profiles->{'default'}->{type} = 'public';
    foreach my $public_profile ($self->{cfg}->Parameters('PUBLIC PROFILES')) {
        $profiles->{lc($public_profile)}->{type} = 'public';
        $profiles->{lc($public_profile)}->{profile_file_name} = $self->{cfg}->val('PUBLIC PROFILES', $public_profile);
    }

    return keys %$profiles;
}

sub lock_on_queue {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'lock_on_queue' );

    return $val;
}

=head2 BackendDBType

Returns a normalized string based on the DB.engine value in the config.

=head3 EXCEPTION

Dies if the value of DB.engine is unrecognized.

=head2 new_DB

Create a new database adapter object according to configuration.

The adapter connects to the database before it is returned.

=head3 INPUT

The database adapter class is selected based on the return value of
BackendDBType().
The database adapter class constructor is called without arguments and is
expected to configure itself according to available global configuration.

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
    my ($self) = @_;

    # Get DB type from config
    my $dbtype = $self->BackendDBType();
    if (!defined $dbtype) {
        die "Unrecognized DB.engine in backend config";
    }

    # Load and construct DB adapter
    my $dbclass = 'Zonemaster::Backend::DB::' . $dbtype;
    require( join( "/", split( /::/, $dbclass ) ) . ".pm" );
    $dbclass->import();
    $log->notice("Constructing database adapter: $dbclass");

    my $db = $dbclass->new({ config => $self });

    # Connect or die
    $db->dbh;

    return $db;
}

=head2 new_PM

Create a new processing manager object according to configuration.

=head3 INPUT

The values of the following attributes affect the construction of the returned object:

=over

=item MaxZonemasterExecutionTime

=item NumberOfProcessesForBatchTesting

=item NumberOfProcessesForFrontendTesting

=back

=head3 RETURNS

A configured L<Parallel::ForkManager> object.

=cut

sub new_PM {
    my $self = shift;

    my $maximum_processes = $self->NumberOfProcessesForFrontendTesting() + $self->NumberOfProcessesForBatchTesting();

    my $timeout = $self->MaxZonemasterExecutionTime();

    my %times;

    my $pm = Parallel::ForkManager->new( $maximum_processes );
    $pm->set_waitpid_blocking_sleep( 0 ) if $pm->can( 'set_waitpid_blocking_sleep' );

    $pm->run_on_wait(
        sub {
            foreach my $pid ( $pm->running_procs ) {
                my $diff = time() - $times{$pid}[0];
                my $id   = $times{$pid}[1];

                if ( $diff > $timeout ) {
                    $log->warning( "Worker process (pid $pid, testid $id): Timeout, sending SIGKILL" );
                    kill 9, $pid;
                }
            }
        },
        1
    );

    $pm->run_on_start(
        sub {
            my ( $pid, $id ) = @_;

            $times{$pid} = [ time(), $id ];
        }
    );

    $pm->run_on_finish(
        sub {
            my ( $pid, $exitcode, $id, $signal ) = @_;

            delete $times{$pid};

            my $message =
              ( $signal )
              ? "Terminated by signal $signal (SIG$SIG_NAME[$signal])"
              : "Terminated with exit code $exitcode";

            $log->notice( "Worker process (pid $pid, testid $id): $message" );
        }
    );

    return $pm;
}

1;

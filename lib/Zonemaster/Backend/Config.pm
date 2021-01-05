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

=head2 Language_Locale_hash

Read LANGUAGE.locale from the configuration (.ini) file and returns
the valid language tags for RPCAPI. The incoming language tag
from RPCAPI is compared to those. The language tags are mapped to
locale setting value.

=head3 INPUT

None

=head3 RETURNS

A hash of valid language tags as keys with set locale value as value.
The hash is never empty.

=cut

sub Language_Locale_hash {
    # There is one special value to capture ambiguous (and therefore
    # not permitted) translation language tags.
    my ($self) = @_;
    my $data = $self->{cfg}->val( 'LANGUAGE', 'locale' );
    $data = 'en_US' unless $data;
    my @localetags = split (/\s+/,$data);
    my %locale;
    foreach my $la (@localetags) {
        die "Incorrect locale tag in LANGUAGE.locale: $la\n" unless $la =~ /^[a-z]{2}_[A-Z]{2}$/;
        die "Repeated locale tag in LANGUAGE.locale: $la\n" if $locale{$la};
        (my $a) = split (/_/,$la); # $a is the language code only
        my $lo = "$la.UTF-8";
        # Set special value if the same language code is used more than once
        # with different country codes.
        if ( $locale{$a} and $locale{$a} ne $lo ) {
            $locale{$a} = 'NOT-UNIQUE';
        }
        else {
            $locale{$a} = $lo;
        }
        $locale{$la} = $lo;
    }
    return %locale;
}

=head2 ListLanguageTags

Read indirectly LANGUAGE.locale from the configuration (.ini) file
and returns a list of valid language tags for RPCAPI. The list can
be retrieved via an RPCAPI method.

=head3 INPUT

None

=head3 RETURNS

An array of valid language tags. The array is never empty.

=cut

sub ListLanguageTags {
    my ($self) = @_;
    my %locale = &Language_Locale_hash($self);
    my @langtags;
    foreach my $key (keys %locale) {
        push @langtags, $key unless $locale{$key} eq 'NOT-UNIQUE';
    }
    return @langtags;
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


=head2 MaxZonemasterExecutionTime

=head3 INPUT

'max_zonemaster_execution_time' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#max_zonemaster_execution_time>.

=head3 RETURNS

Integer (number of seconds)

=cut

sub MaxZonemasterExecutionTime {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'max_zonemaster_execution_time' );

    return ($val)?($val):(10*60);
}


=head2 NumberOfProcessesForFrontendTesting

=head3 INPUT

'number_of_processes_for_frontend_testing' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#number_of_processes_for_frontend_testing>.

=head3 RETURNS

Positive integer (default 600).

=cut

sub NumberOfProcessesForFrontendTesting {
    my ($self) = @_;

    my $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' );
    $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_processes_for_frontend_testing' ) unless ($nb);

    return $nb;
}


=head2 NumberOfProcessesForBatchTesting

=head3 INPUT

'number_of_processes_for_batch_testing' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#number_of_processes_for_batch_testing>.

=head3 RETURNS

Integer.

=cut

sub NumberOfProcessesForBatchTesting {
    my ($self) = @_;

    my $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_professes_for_batch_testing' );
    $nb = $self->{cfg}->val( 'ZONEMASTER', 'number_of_processes_for_batch_testing' ) unless ($nb);

    return $nb;
}


=head2 force_hash_id_use_in_API_starting_from_id

=head3 INPUT

'force_hash_id_use_in_API_starting_from_id' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#force_hash_id_use_in_api_starting_from_id>.

=head3 RETURNS

Integer (default 0).

=cut

sub force_hash_id_use_in_API_starting_from_id {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'force_hash_id_use_in_API_starting_from_id' );

    return ($val)?($val):(0);
}

=head2 lock_on_queue

=head3 INPUT

'lock_on_queue' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#lock_on_queue>.

=head3 RETURNS

Integer (default 0).

=cut

sub lock_on_queue {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'lock_on_queue' );

    return $val;
}


=head2 maximal_number_of_retries

This option is experimental and all edge cases are not fully tested.
Do not use it (keep the default value "0"), or use it with care.

=head3 INPUT

'maximal_number_of_retries' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#maximal_number_of_retries>.

=head3 RETURNS

A scalar value of the number of retries (default 0).

=cut

sub maximal_number_of_retries {
    my ($self) = @_;

    my $val = $self->{cfg}->val( 'ZONEMASTER', 'maximal_number_of_retries' );

    return ($val)?($val):(0);
}


=head2 age_reuse_previous_test

=head3 INPUT

'age_reuse_previous_test' from [ZONEMASTER] section in ini file (in seconds). See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#age_reuse_previous_test>.

=head3 RETURNS

A scalar value of the number of minutes old the previous test with the same
parameters can be when it is reused instead of starting a new test (default
10). Note that it returns in minutes, whereas the input is in seconds.

=cut

sub age_reuse_previous_test {
    my ($self) = @_;
    my $val = $self->{cfg}->val( 'ZONEMASTER', 'age_reuse_previous_test' );
    $val = ($val > 0) ? $val : 0;
    $val = int ( ($val / 60) + 0.5); # in minutes
    return ($val)? $val : 10;
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

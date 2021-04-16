package Zonemaster::Backend::Config;
use strict;
use warnings;
use 5.14.2;

our $VERSION = '1.1.0';

use Config::IniFiles;
use Config;
use File::ShareDir qw[dist_file];
use File::Slurp qw( read_file );
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
    my ( $class ) = @_;

    $log->notice( "Loading config: $path" );
    my $text = read_file $path;

    my $obj = eval { $class->parse( $text ) };
    if ( $@ ) {
        die "File $path: $@";
    }

    return $obj;
}

=head2 parse

Parse a new Zonemaster::Backend::Config from the contents of a
L<configuration|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md>
file.

    my $config = Zonemaster::Backend::Config->parse(
        q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
        }
    );

Throws an exception if the given configuration file contains errors.

=cut

sub parse {
    my ( $class, $text ) = @_;

    my $obj = bless( {}, $class );

    my $ini = Config::IniFiles->new( -file => \$text )
      or die "Failed to parse config: " . join( '; ', @Config::IniFiles::errors ) . "\n";

    # Validate, normalize, and apply default values
    {
        my $engine = $ini->val( 'DB', 'engine' );
        eval {
            $engine = $obj->check_db($engine);
        };
        if ($@) {
            die "Unknown config value DB.engine: $engine\n";
        }
        $obj->{_DB_engine} = $engine;
    }

    $obj->{_DB_polling_interval}                                 = $ini->val( 'DB',         'polling_interval',                         undef );
    $obj->{_MYSQL_host}                                          = $ini->val( 'MYSQL',      'host',                                     undef );
    $obj->{_MYSQL_user}                                          = $ini->val( 'MYSQL',      'user',                                     undef );
    $obj->{_MYSQL_password}                                      = $ini->val( 'MYSQL',      'password',                                 undef );
    $obj->{_MYSQL_database}                                      = $ini->val( 'MYSQL',      'database',                                 undef );
    $obj->{_POSTGRESQL_host}                                     = $ini->val( 'POSTGRESQL', 'host',                                     undef );
    $obj->{_POSTGRESQL_user}                                     = $ini->val( 'POSTGRESQL', 'user',                                     undef );
    $obj->{_POSTGRESQL_password}                                 = $ini->val( 'POSTGRESQL', 'password',                                 undef );
    $obj->{_POSTGRESQL_database}                                 = $ini->val( 'POSTGRESQL', 'database',                                 undef );
    $obj->{_SQLITE_database_file}                                = $ini->val( 'SQLITE',     'database_file',                            undef );
    $obj->{_ZONEMASTER_max_zonemaster_execution_time}            = $ini->val( 'ZONEMASTER', 'max_zonemaster_execution_time',            '600' );
    $obj->{_ZONEMASTER_maximal_number_of_retries}                = $ini->val( 'ZONEMASTER', 'maximal_number_of_retries',                '0' );
    $obj->{_ZONEMASTER_number_of_processes_for_frontend_testing} = $ini->val( 'ZONEMASTER', 'number_of_processes_for_frontend_testing', undef );
    $obj->{_ZONEMASTER_number_of_processes_for_batch_testing}    = $ini->val( 'ZONEMASTER', 'number_of_processes_for_batch_testing',    undef );
    $obj->{_ZONEMASTER_lock_on_queue}                            = $ini->val( 'ZONEMASTER', 'lock_on_queue',                            undef );
    $obj->{_ZONEMASTER_age_reuse_previous_test}                  = $ini->val( 'ZONEMASTER', 'age_reuse_previous_test',                  '600' );

    $obj->{_LANGUAGE_locale} = {};
    for my $locale_tag ( split /\s+/, $ini->val( 'LANGUAGE', 'locale' ) || 'en_US' ) {
        $locale_tag =~ /^[a-z]{2}_[A-Z]{2}$/
          or die "Illegal locale tag in LANGUAGE.locale: $locale_tag\n";

        !exists $obj->{_LANGUAGE_locale}{$locale_tag}
          or die "Repeated locale tag in LANGUAGE.locale: $locale_tag\n";

        $obj->{_LANGUAGE_locale}{$locale_tag} = 1;
    }

    $obj->{_public_profiles} = {
        default => '',
    };
    for my $name ( $ini->Parameters( 'PUBLIC PROFILES' ) ) {
        $obj->{_public_profiles}{lc $name} = $ini->val( 'PUBLIC PROFILES', $name );
    }
    $obj->{_private_profiles} = {};
    for my $name ( $ini->Parameters( 'PRIVATE PROFILES' ) ) {
        $obj->{_private_profiles}{lc $name} = $ini->val( 'PRIVATE PROFILES', $name );
    }

    # Handle deprecated properties
    if ( defined( my $value = $ini->val( 'DB', 'database_host' ) ) ) {
        $log->warning( "Use of deprecated config property DB.database_host. Use MYSQL.host or POSTGRESQL.host instead." );

        $obj->{_MYSQL_host} = $value
          if $obj->BackendDBType eq 'MySQL' && !defined $obj->MYSQL_host;

        $obj->{_POSTGRESQL_host} = $value
          if $obj->BackendDBType eq 'PostgreSQL' && !defined $obj->POSTGRESQL_host;
    }
    if ( defined( my $value = $ini->val( 'DB', 'user' ) ) ) {
        $log->warning( "Use of deprecated config property DB.user. Use MYSQL.user or POSTGRESQL.user instead." );

        $obj->{_MYSQL_user} = $value
          if $obj->BackendDBType eq 'MySQL' && !defined $obj->MYSQL_user;

        $obj->{_POSTGRESQL_user} = $value
          if $obj->BackendDBType eq 'PostgreSQL' && !defined $obj->POSTGRESQL_user;
    }
    if ( defined( my $value = $ini->val( 'DB', 'password' ) ) ) {
        $log->warning( "Use of deprecated config property DB.password. Use MYSQL.password or POSTGRESQL.password instead." );

        $obj->{_MYSQL_password} = $value
          if $obj->BackendDBType eq 'MySQL' && !defined $obj->MYSQL_password;

        $obj->{_POSTGRESQL_password} = $value
          if $obj->BackendDBType eq 'PostgreSQL' && !defined $obj->POSTGRESQL_password;
    }
    if ( defined( my $value = $ini->val( 'DB', 'database_name' ) ) ) {
        $log->warning( "Use of deprecated config property DB.database_name. Use MYSQL.database, POSTGRESQL.database or SQLITE.database_file instead." );

        $obj->{_MYSQL_database} = $value
          if $obj->BackendDBType eq 'MySQL' && !defined $obj->MYSQL_database;

        $obj->{_POSTGRESQL_database} = $value
          if $obj->BackendDBType eq 'PostgreSQL' && !defined $obj->POSTGRESQL_database;

        $obj->{_SQLITE_database_file} = $value
          if $obj->BackendDBType eq 'SQLite' && !defined $obj->SQLITE_database_file;
    }
    if ( defined( my $value = $ini->val( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' ) ) ) {
        $log->warning( "Use of deprecated config property ZONEMASTER.number_of_professes_for_frontend_testing. Use ZONEMASTER.number_of_processes_for_frontend_testing instead." );

        $obj->{_ZONEMASTER_number_of_processes_for_frontend_testing} = $value
          if !defined $obj->NumberOfProcessesForFrontendTesting;
    }
    if ( defined( my $value = $ini->val( 'ZONEMASTER', 'number_of_professes_for_batch_testing' ) ) ) {
        $log->warning( "Use of deprecated config property ZONEMASTER.number_of_professes_for_batch_testing. Use ZONEMASTER.number_of_processes_for_batch_testing instead." );

        $obj->{_ZONEMASTER_number_of_processes_for_batch_testing} = $value
          if !defined $obj->NumberOfProcessesForBatchTesting;
    }

    return $obj;
}

sub check_db {
    my ( $self, $db ) = @_;

    if ( lc $db eq 'sqlite' ) {
        return 'SQLite';
    }
    elsif ( lc $db eq 'postgresql' ) {
        return 'PostgreSQL';
    }
    elsif ( lc $db eq 'mysql' ) {
        return 'MySQL';
    }
    else {
        die "Unknown database '$db', should be one of SQLite, MySQL or PostgreSQL\n";
    }
}

sub BackendDBType {
    my ($self) = @_;

    return $self->{_DB_engine};
}

=head2 MYSQL_database

Returns the L<MYSQL.database|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database>
property from the loaded config, or the L<DB.database_name|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_name>
property if it is unspecified.

=cut

sub MYSQL_database {
    my ( $self ) = @_;

    return $self->{_MYSQL_database};
}

=head2 MySQL_host

Returns the L<MYSQL.host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#host>
property from the loaded config, or the L<DB.database_host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_host>
property if it is unspecified.

=cut

sub MYSQL_host {
    my ( $self ) = @_;

    return $self->{_MYSQL_host};
}

=head2 MYSQL_password

Returns the L<MYSQL.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password-1>
property from the loaded config, or the L<DB.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password>
property if it is unspecified.

=cut

sub MYSQL_password {
    my ( $self ) = @_;

    return $self->{_MYSQL_password};
}

=head2 MYSQL_user

Returns the L<MYSQL.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user-1>
property from the loaded config, or the L<DB.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user>
property if it is unspecified.

=cut

sub MYSQL_user {
    my ( $self ) = @_;

    return $self->{_MYSQL_user};
}

=head2 POSTGRESQL_database

Returns the L<POSTGRESQL.database|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database-1>
property from the loaded config, or the L<DB.database_name|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_name>
property if it is unspecified.

=cut

sub POSTGRESQL_database {
    my ( $self ) = @_;

    return $self->{_POSTGRESQL_database};
}

=head2 POSTGRESQL_host

Returns the L<POSTGRESQL.host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#host-1>
property from the loaded config, or the L<DB.database_host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_host>
property if it is unspecified.

=cut

sub POSTGRESQL_host {
    my ( $self ) = @_;

    return $self->{_POSTGRESQL_host};
}

=head2 POSTGRESQL_password

Returns the L<POSTGRESQL.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password-2>
property from the loaded config, or the L<DB.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password>
property if it is unspecified.

=cut

sub POSTGRESQL_password {
    my ( $self ) = @_;

    return $self->{_POSTGRESQL_password};
}

=head2 POSTGRESQL_user

Returns the L<POSTGRESQL.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user-2>
property from the loaded config, or the L<DB.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user>
property if it is unspecified.

=cut

sub POSTGRESQL_user {
    my ( $self ) = @_;

    return $self->{_POSTGRESQL_user};
}

=head2 SQLITE_database_file

Returns the L<SQLITE.database_file|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_file>
property from the loaded config, or the L<DB.database_name|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_name>
property if it is unspecified.

=cut

sub SQLITE_database_file {
    my ( $self ) = @_;

    return $self->{_SQLITE_database_file};
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
    my @localetags = keys %{ $self->{_LANGUAGE_locale} };
    my %locale;
    foreach my $la (@localetags) {
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

sub PollingInterval {
    my ($self) = @_;

    return $self->{_DB_polling_interval};
}


=head2 MaxZonemasterExecutionTime

=head3 INPUT

'max_zonemaster_execution_time' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#max_zonemaster_execution_time>.

=head3 RETURNS

Integer (number of seconds), default 600.

=cut

sub MaxZonemasterExecutionTime {
    my ($self) = @_;

    return $self->{_ZONEMASTER_max_zonemaster_execution_time};
}


=head2 NumberOfProcessesForFrontendTesting

=head3 INPUT

'number_of_processes_for_frontend_testing' from [ZONEMASTER] section in ini file. See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#number_of_processes_for_frontend_testing>.

=head3 RETURNS

Positive integer.

=cut

sub NumberOfProcessesForFrontendTesting {
    my ($self) = @_;

    return $self->{_ZONEMASTER_number_of_processes_for_frontend_testing};
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

    return $self->{_ZONEMASTER_number_of_processes_for_batch_testing};
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

    return $self->{_ZONEMASTER_lock_on_queue};
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

    return $self->{_ZONEMASTER_maximal_number_of_retries};
}


=head2 age_reuse_previous_test

=head3 INPUT

'age_reuse_previous_test' from [ZONEMASTER] section in ini file (in seconds). See
L<https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#age_reuse_previous_test>.

=head3 RETURNS

A scalar value of the number of seconds old the previous test with the same
parameters can be when it is reused instead of starting a new test (default
600).

=cut

sub age_reuse_previous_test {
    my ($self) = @_;

    return $self->{_ZONEMASTER_age_reuse_previous_test};
}


sub ReadProfilesInfo {
    my ($self) = @_;

    my $profiles;
    foreach my $public_profile ( keys %{ $self->{_public_profiles} } ) {
        $profiles->{$public_profile}->{type} = 'public';
        $profiles->{$public_profile}->{profile_file_name} = $self->{_public_profiles}{$public_profile};
    }

    foreach my $private_profile ( keys %{ $self->{_private_profiles} } ) {
        $profiles->{$private_profile}->{type} = 'private';
        $profiles->{$private_profile}->{profile_file_name} = $self->{_private_profiles}{$private_profile};
    }

    return $profiles;
}

sub ListPublicProfiles {
    my ($self) = @_;

    return keys %{ $self->{_public_profiles} };
}

=head2 check_db

Returns a normalized string based on the supported databases.

=head3 EXCEPTION

Dies if the value is not one of SQLite, PostgreSQL or MySQL.

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

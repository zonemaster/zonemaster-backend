package Zonemaster::Backend::Config;
use strict;
use warnings;
use 5.14.2;

our $VERSION = '1.1.0';

use Carp qw( confess );
use Config::IniFiles;
use Config;
use File::ShareDir qw[dist_file];
use File::Slurp qw( read_file );
use Log::Any qw( $log );
use Readonly;
use Zonemaster::Backend::Validator qw( :untaint );
use Zonemaster::Backend::DB;

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

=head1 CONSTRUCTORS

=head2 load_config

A wrapper around L<parse> that also determines where the config file is located
in the file system and reads it.

Throws an exception if the determined configuration file cannot be read.
See L<parse> for details on additional parsing-related error modes.

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

Construct a new Zonemaster::Backend::Config based on a given configuration.

    my $config = Zonemaster::Backend::Config->parse(
        q{
            [DB]
            engine = SQLite

            [SQLITE]
            database_file = /var/db/zonemaster.sqlite
        }
    );

The configuration is interpreted according to the
L<configuration format specification|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md>.

Returns a new Zonemaster::Backend::Config instance with its properties set to
normalized and untainted values according to the given configuration with
defaults according to the configuration format.

Emits a log warning with a deprecation message for each deprecated property that
is present.

Throws an exception if the given configuration contains errors.

In a valid config file:

=over 4

=item

all required properties are present, and

=item

all sections and properties are recognized.

=back

=cut

sub parse {
    my ( $class, $text ) = @_;

    my $obj = bless( {}, $class );
    $obj->{_public_profiles}  = {};
    $obj->{_private_profiles} = {};

    my $ini = Config::IniFiles->new( -file => \$text )
      or die "Failed to parse config: " . join( '; ', @Config::IniFiles::errors ) . "\n";

    my $get_and_clear = sub {    # Read and clear a property from a Config::IniFiles object.
        my ( $section, $param ) = @_;
        my ( $value, @extra ) = $ini->val( $section, $param );
        if ( @extra ) {
            die "Property not unique: $section.$param\n";
        }
        $ini->delval( $section, $param );
        return $value;
    };

    # Validate section names
    {
        my %sections = map { $_ => 1 } ( 'DB', 'MYSQL', 'POSTGRESQL', 'SQLITE', 'LANGUAGE', 'PUBLIC PROFILES', 'PRIVATE PROFILES', 'ZONEMASTER' );
        for my $section ( $ini->Sections ) {
            if ( !exists $sections{$section} ) {
                die "config: unrecognized section: $section\n";
            }
        }
    }

    # Assign default values
    $obj->_set_DB_polling_interval( '0.5' );
    $obj->_set_MYSQL_port( '3306' );
    $obj->_set_POSTGRESQL_port( '5432' );
    $obj->_set_ZONEMASTER_max_zonemaster_execution_time( '600' );
    $obj->_set_ZONEMASTER_maximal_number_of_retries( '0' );
    $obj->_set_ZONEMASTER_number_of_processes_for_frontend_testing( '20' );
    $obj->_set_ZONEMASTER_number_of_processes_for_batch_testing( '20' );
    $obj->_set_ZONEMASTER_lock_on_queue( '0' );
    $obj->_set_ZONEMASTER_age_reuse_previous_test( '600' );
    $obj->_add_LANGUAGE_locale( 'en_US' );
    $obj->_add_public_profile( 'default', undef );

    # Assign property values (part 1/2)
    if ( defined( my $value = $get_and_clear->( 'DB', 'engine' ) ) ) {
        $obj->_set_DB_engine( $value );
    }

    # Check required properties (part 1/2)
    if ( !defined $obj->DB_engine ) {
        die "config: missing required property DB.engine\n";
    }

    # Check deprecated properties and assign fallback values
    my @warnings;
    if ( defined( my $value = $get_and_clear->( 'DB', 'database_host' ) ) ) {
        push @warnings, "Use of deprecated config property DB.database_host. Use MYSQL.host or POSTGRESQL.host instead.";

        $obj->_set_MYSQL_host( $value )
          if $obj->DB_engine eq 'MySQL';

        $obj->_set_POSTGRESQL_host( $value )
          if $obj->DB_engine eq 'PostgreSQL';
    }

    if ( defined( my $value = $get_and_clear->( 'DB', 'user' ) ) ) {
        push @warnings, "Use of deprecated config property DB.user. Use MYSQL.user or POSTGRESQL.user instead.";

        $obj->_set_MYSQL_user( $value )
          if $obj->DB_engine eq 'MySQL';

        $obj->_set_POSTGRESQL_user( $value )
          if $obj->DB_engine eq 'PostgreSQL';
    }

    if ( defined( my $value = $get_and_clear->( 'DB', 'password' ) ) ) {
        push @warnings, "Use of deprecated config property DB.password. Use MYSQL.password or POSTGRESQL.password instead.";

        $obj->_set_MYSQL_password( $value )
          if $obj->DB_engine eq 'MySQL';

        $obj->_set_POSTGRESQL_password( $value )
          if $obj->DB_engine eq 'PostgreSQL';
    }
    if ( defined( my $value = $get_and_clear->( 'DB', 'database_name' ) ) ) {
        push @warnings, "Use of deprecated config property DB.database_name. Use MYSQL.database, POSTGRESQL.database or SQLITE.database_file instead.";

        $obj->_set_MYSQL_database( $value )
          if $obj->DB_engine eq 'MySQL';

        $obj->_set_POSTGRESQL_database( $value )
          if $obj->DB_engine eq 'PostgreSQL';

        $obj->_set_SQLITE_database_file( $value )
          if $obj->DB_engine eq 'SQLite';
    }
    if ( defined( my $value = $ini->val( 'LANGUAGE', 'locale' ) ) ) {
        if ( $value eq "" ) {
            push @warnings, "Use of empty LANGUAGE.locale property is deprecated. Remove the LANGUAGE.locale entry or specify LANGUAGE.locale = en_US instead.";
        }
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'number_of_professes_for_frontend_testing' ) ) ) {
        push @warnings, "Use of deprecated config property ZONEMASTER.number_of_professes_for_frontend_testing. Use ZONEMASTER.number_of_processes_for_frontend_testing instead.";

        $obj->_set_ZONEMASTER_number_of_processes_for_frontend_testing( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'number_of_professes_for_batch_testing' ) ) ) {
        push @warnings, "Use of deprecated config property ZONEMASTER.number_of_professes_for_batch_testing. Use ZONEMASTER.number_of_processes_for_batch_testing instead.";

        $obj->_set_ZONEMASTER_number_of_processes_for_batch_testing( $value );
    }

    # Assign property values (part 2/2)
    if ( defined( my $value = $get_and_clear->( 'DB', 'polling_interval' ) ) ) {
        $obj->_set_DB_polling_interval( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'MYSQL', 'host' ) ) ) {
        $obj->_set_MYSQL_host( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'MYSQL', 'port' ) ) ) {
        if ( $obj->MYSQL_host eq 'localhost' ) {
            push @warnings, "MYSQL.port is disregarded if MYSQL.host is set to 'localhost'";
        }
        $obj->{_MYSQL_port} = $value;
    }
    if ( defined( my $value = $get_and_clear->( 'MYSQL', 'user' ) ) ) {
        $obj->_set_MYSQL_user( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'MYSQL', 'password' ) ) ) {
        $obj->_set_MYSQL_password( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'MYSQL', 'database' ) ) ) {
        $obj->_set_MYSQL_database( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'POSTGRESQL', 'host' ) ) ) {
        $obj->_set_POSTGRESQL_host( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'POSTGRESQL', 'port' ) ) ) {
        $obj->{_POSTGRESQL_port} = $value;
    }
    if ( defined( my $value = $get_and_clear->( 'POSTGRESQL', 'user' ) ) ) {
        $obj->_set_POSTGRESQL_user( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'POSTGRESQL', 'password' ) ) ) {
        $obj->_set_POSTGRESQL_password( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'POSTGRESQL', 'database' ) ) ) {
        $obj->_set_POSTGRESQL_database( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'SQLITE', 'database_file' ) ) ) {
        $obj->_set_SQLITE_database_file( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'max_zonemaster_execution_time' ) ) ) {
        $obj->_set_ZONEMASTER_max_zonemaster_execution_time( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'maximal_number_of_retries' ) ) ) {
        $obj->_set_ZONEMASTER_maximal_number_of_retries( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'number_of_processes_for_frontend_testing' ) ) ) {
        $obj->_set_ZONEMASTER_number_of_processes_for_frontend_testing( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'number_of_processes_for_batch_testing' ) ) ) {
        $obj->_set_ZONEMASTER_number_of_processes_for_batch_testing( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'lock_on_queue' ) ) ) {
        $obj->_set_ZONEMASTER_lock_on_queue( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'ZONEMASTER', 'age_reuse_previous_test' ) ) ) {
        $obj->_set_ZONEMASTER_age_reuse_previous_test( $value );
    }
    if ( defined( my $value = $get_and_clear->( 'LANGUAGE', 'locale' ) ) ) {
        if ( $value ne "" ) {
            $obj->_reset_LANGUAGE_locale();
            my $default_set = 0;
            for my $locale_tag ( split / +/, $value ) {
                $obj->_add_LANGUAGE_locale( $locale_tag );
                if ( not $default_set ) {
                    $obj->_set_LANGUAGE_default_locale( $locale_tag );
                    $default_set = 1;
                }
            }
        }
    }

    for my $name ( $ini->Parameters( 'PUBLIC PROFILES' ) ) {
        my $path = $get_and_clear->( 'PUBLIC PROFILES', $name );
        $obj->_add_public_profile( $name, $path );
    }

    for my $name ( $ini->Parameters( 'PRIVATE PROFILES' ) ) {
        my $path = $get_and_clear->( 'PRIVATE PROFILES', $name );
        $obj->_add_private_profile( $name, $path );
    }

    # Check required propertys (part 2/2)
    if ( $obj->DB_engine eq 'MySQL' ) {
        die "config: missing required property MYSQL.host (required when DB.engine = MySQL and DB.database_host is unset)\n"
          if !defined $obj->MYSQL_host;

        die "config: missing required property MYSQL.user (required when DB.engine = MySQL and DB.user is unset)\n"
          if !defined $obj->MYSQL_user;

        die "config: missing required property MYSQL.password (required when DB.engine = MySQL and DB.password is unset)\n"
          if !defined $obj->MYSQL_password;

        die "config: missing required property MYSQL.database (required when DB.engine = MySQL and DB.database_name is unset)\n"
          if !defined $obj->MYSQL_database;
    }
    elsif ( $obj->DB_engine eq 'PostgreSQL' ) {
        die "config: missing required property POSTGRESQL.host (required when DB.engine = PostgreSQL and DB.database_host is unset)\n"
          if !defined $obj->POSTGRESQL_host;

        die "config: missing required property POSTGRESQL.user (required when DB.engine = PostgreSQL and DB.user is unset)\n"
          if !defined $obj->POSTGRESQL_user;

        die "config: missing required property POSTGRESQL.password (required when DB.engine = PostgreSQL and DB.password is unset)\n"
          if !defined $obj->POSTGRESQL_password;

        die "config: missing required property POSTGRESQL.database (required when DB.engine = PostgreSQL and DB.database_name is unset)\n"
          if !defined $obj->POSTGRESQL_database;
    }
    elsif ( $obj->DB_engine eq 'SQLite' ) {
        die "config: missing required property SQLITE.database_file (required when DB.engine = SQLite and DB.database_name is unset)\n"
          if !defined $obj->SQLITE_database_file;
    }

    # Check unknown property names
    {
        my @unrecognized;
        for my $section ( $ini->Sections ) {
            for my $param ( $ini->Parameters( $section ) ) {
                push @unrecognized, "$section.$param";
            }
        }
        if ( @unrecognized ) {
            die "config: unrecognized property(s): " . join( ", ", sort @unrecognized ) . "\n";
        }
    }

    # Emit deprecation warnings
    for my $message ( @warnings ) {
        $log->warning( $message );
    }

    return $obj;
}

=head1 METHODS

=head2 check_db

Returns a normalized string based on the supported databases.

=head3 EXCEPTION

Dies if the value is not one of SQLite, PostgreSQL or MySQL.

=cut

sub check_db {
    my ( $self, $db ) = @_;

    $db = untaint_engine_type( $db )    #
      // die "Unknown database '$db', should be one of SQLite, MySQL or PostgreSQL\n";

    return _normalize_engine_type( $db );
}


=head2 DB_engine

Get the value of L<DB.engine|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#engine>.

Returns one of C<"SQLite">, C<"PostgreSQL"> or C<"MySQL">.

=cut

sub DB_engine {
    my ( $self ) = @_;
    return $self->{_DB_engine};
}

sub _set_DB_engine {
    my ( $self, $value ) = @_;

    $value = untaint_engine_type( $value )    #
      // die "Invalid value for DB.engine: $value\n";

    $self->{_DB_engine} = _normalize_engine_type( $value );
    return;
}

=head2 DB_polling_interval

Get the value of L<DB.polling_interval|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#polling_interval>.

Returns a number.


=head2 MYSQL_database

Get the value of L<MYSQL.database|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database>.

Returns a string.


=head2 MYSQL_host

Get the value of L<MYSQL.host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#host>.

Returns a string.


=head2 MYSQL_port

Returns the L<MYSQL.port|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#port>
property from the loaded config.

Returns a number.


=head2 MYSQL_password

Get the value of L<MYSQL.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password-1>.

Returns a string.


=head2 MYSQL_user

Get the value of L<MYSQL.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user-1>.

Returns a string.


=head2 POSTGRESQL_database

Get the value of L<POSTGRESQL.database|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database-1>.

Returns a string.


=head2 POSTGRESQL_host

Get the value of L<POSTGRESQL.host|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#host-1>.

Returns a string.


=head2 POSTGRESQL_port

Returns the L<POSTGRESQL.port|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#port-1>
property from the loaded config.

Returns a number.


=head2 POSTGRESQL_password

Get the value of L<POSTGRESQL.password|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#password-2>.

Returns a string.


=head2 POSTGRESQL_user

Get the value of L<POSTGRESQL.user|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#user-2>.

Returns a string.


=head2 SQLITE_database_file

Get the value of L<SQLITE.database_file|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#database_file>.

Returns a string.


=head2 LANGUAGE_locale

Get the value of L<LANGUAGE.locale|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#locale>.

Returns a mapping from two-letter locale tag prefixes to sets of full locale
tags.
This is represented by a hash of hashrefs where all second level values are
C<1>.

E.g.:

    (
        en => {
            en_GB => 1,
            en_US => 1,
        },
        sv => {
            sv_SE => 1,
        },
    )

=head2 LANGUAGE_default_locale

Get the first locale passed to the L<locale list|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#locale> in the configuration file.

Returns a string.


=head2 PUBLIC_PROFILES

Get the set of L<PUBLIC PROFILES|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#public-profiles-and-private-profiles-sections>.

Returns a hash mapping profile names to profile paths.
The profile names are normalized to lowercase.
Profile paths are either strings or C<undef>.
C<undef> means that the Zonemaster Engine default profile should be used.


=head2 PRIVATE_PROFILES

Get the set of L<PRIVATE PROFILES|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#public-profiles-and-private-profiles-sections>.

Returns a hash mapping profile names to profile paths.
The profile names are normalized to lowercase.
Profile paths are always strings (contrast with L<PUBLIC_PROFILES>).


=head2 ZONEMASTER_max_zonemaster_execution_time

Get the value of L<ZONEMASTER.max_zonemaster_execution_time|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#max_zonemaster_execution_time>.

Returns a number.


=head2 ZONEMASTER_number_of_processes_for_frontend_testing

Get the value of
L<ZONEMASTER.number_of_processes_for_frontend_testing|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#number_of_processes_for_frontend_testing>.

Returns a number.


=head2 ZONEMASTER_number_of_processes_for_batch_testing

Get the value of
L<ZONEMASTER.number_of_processes_for_batch_testing|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#number_of_processes_for_batch_testing>.

Returns a number.


=head2 ZONEMASTER_lock_on_queue

Get the value of
L<ZONEMASTER.lock_on_queue|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#lock_on_queue>.

Returns a number.


=head2 ZONEMASTER_maximal_number_of_retries

Get the value of
L<ZONEMASTER.maximal_number_of_retries|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#maximal_number_of_retries>.

Returns a number.


=head2 ZONEMASTER_age_reuse_previous_test

Get the value of
L<ZONEMASTER.age_reuse_previous_test|https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Configuration.md#age_reuse_previous_test>.

Returns a number.

=cut

# Getters for the properties documented above
sub DB_polling_interval                                 { return $_[0]->{_DB_polling_interval}; }
sub MYSQL_host                                          { return $_[0]->{_MYSQL_host}; }
sub MYSQL_port                                          { return $_[0]->{_MYSQL_port}; }
sub MYSQL_user                                          { return $_[0]->{_MYSQL_user}; }
sub MYSQL_password                                      { return $_[0]->{_MYSQL_password}; }
sub MYSQL_database                                      { return $_[0]->{_MYSQL_database}; }
sub POSTGRESQL_host                                     { return $_[0]->{_POSTGRESQL_host}; }
sub POSTGRESQL_port                                     { return $_[0]->{_POSTGRESQL_port}; }
sub POSTGRESQL_user                                     { return $_[0]->{_POSTGRESQL_user}; }
sub POSTGRESQL_password                                 { return $_[0]->{_POSTGRESQL_password}; }
sub POSTGRESQL_database                                 { return $_[0]->{_POSTGRESQL_database}; }
sub SQLITE_database_file                                { return $_[0]->{_SQLITE_database_file}; }
sub LANGUAGE_locale                                     { return %{ $_[0]->{_LANGUAGE_locale} }; }
sub LANGUAGE_default_locale                             { return $_[0]->{_LANGUAGE_default_locale}; }
sub PUBLIC_PROFILES                                     { return %{ $_[0]->{_public_profiles} }; }
sub PRIVATE_PROFILES                                    { return %{ $_[0]->{_private_profiles} }; }
sub ZONEMASTER_max_zonemaster_execution_time            { return $_[0]->{_ZONEMASTER_max_zonemaster_execution_time}; }
sub ZONEMASTER_maximal_number_of_retries                { return $_[0]->{_ZONEMASTER_maximal_number_of_retries}; }
sub ZONEMASTER_lock_on_queue                            { return $_[0]->{_ZONEMASTER_lock_on_queue}; }
sub ZONEMASTER_number_of_processes_for_frontend_testing { return $_[0]->{_ZONEMASTER_number_of_processes_for_frontend_testing}; }
sub ZONEMASTER_number_of_processes_for_batch_testing    { return $_[0]->{_ZONEMASTER_number_of_processes_for_batch_testing}; }
sub ZONEMASTER_age_reuse_previous_test                  { return $_[0]->{_ZONEMASTER_age_reuse_previous_test}; }

# Compile time generation of setters for the properties documented above
UNITCHECK {
    _create_setter( '_set_DB_polling_interval',                                 '_DB_polling_interval',                                 \&untaint_strictly_positive_millis );
    _create_setter( '_set_MYSQL_host',                                          '_MYSQL_host',                                          \&untaint_host );
    _create_setter( '_set_MYSQL_port',                                          '_MYSQL_port',                                          \&untaint_strictly_positive_int );
    _create_setter( '_set_MYSQL_user',                                          '_MYSQL_user',                                          \&untaint_mariadb_user );
    _create_setter( '_set_MYSQL_password',                                      '_MYSQL_password',                                      \&untaint_password );
    _create_setter( '_set_MYSQL_database',                                      '_MYSQL_database',                                      \&untaint_mariadb_database );
    _create_setter( '_set_POSTGRESQL_host',                                     '_POSTGRESQL_host',                                     \&untaint_host );
    _create_setter( '_set_POSTGRESQL_port',                                     '_POSTGRESQL_port',                                     \&untaint_strictly_positive_int );
    _create_setter( '_set_POSTGRESQL_user',                                     '_POSTGRESQL_user',                                     \&untaint_postgresql_ident );
    _create_setter( '_set_POSTGRESQL_password',                                 '_POSTGRESQL_password',                                 \&untaint_password );
    _create_setter( '_set_POSTGRESQL_database',                                 '_POSTGRESQL_database',                                 \&untaint_postgresql_ident );
    _create_setter( '_set_SQLITE_database_file',                                '_SQLITE_database_file',                                \&untaint_abs_path );
    _create_setter( '_set_ZONEMASTER_max_zonemaster_execution_time',            '_ZONEMASTER_max_zonemaster_execution_time',            \&untaint_strictly_positive_int );
    _create_setter( '_set_ZONEMASTER_maximal_number_of_retries',                '_ZONEMASTER_maximal_number_of_retries',                \&untaint_non_negative_int );
    _create_setter( '_set_ZONEMASTER_lock_on_queue',                            '_ZONEMASTER_lock_on_queue',                            \&untaint_non_negative_int );
    _create_setter( '_set_ZONEMASTER_number_of_processes_for_frontend_testing', '_ZONEMASTER_number_of_processes_for_frontend_testing', \&untaint_strictly_positive_int );
    _create_setter( '_set_ZONEMASTER_number_of_processes_for_batch_testing',    '_ZONEMASTER_number_of_processes_for_batch_testing',    \&untaint_non_negative_int );
    _create_setter( '_set_ZONEMASTER_age_reuse_previous_test',                  '_ZONEMASTER_age_reuse_previous_test',                  \&untaint_strictly_positive_int );
    _create_setter( '_set_LANGUAGE_default_locale',                             '_LANGUAGE_default_locale',                             \&untaint_locale_tag );
}

=head2 new_DB

Create a new database adapter object according to configuration.

The adapter connects to the database before it is returned.

=head3 INPUT

The database adapter class is selected based on the return value of
L<DB_engine>.
The database adapter class constructor is called without arguments and is
expected to configure itself according to available global configuration.

=head3 RETURNS

A configured L<Zonemaster::Backend::DB> object.

=head3 EXCEPTIONS

=over 4

=item Dies if no adapter for the configured database engine can be loaded.

=item Dies if the adapter is unable to connect to the database.

=back

=cut

sub new_DB {
    my ( $self ) = @_;

    my $dbtype  = $self->DB_engine;
    my $dbclass = Zonemaster::Backend::DB->get_db_class( $dbtype );
    my $db      = $dbclass->from_config( $self );

    return $db;
}

=head2 new_PM

Create a new processing manager object according to configuration.

=head3 INPUT

The values of the following attributes affect the construction of the returned object:

=over

=item ZONEMASTER_max_zonemaster_execution_time

=item ZONEMASTER_number_of_processes_for_batch_testing

=item ZONEMASTER_number_of_processes_for_frontend_testing

=back

=head3 RETURNS

A configured L<Parallel::ForkManager> object.

=cut

sub new_PM {
    my $self = shift;

    my $maximum_processes = $self->ZONEMASTER_number_of_processes_for_frontend_testing + $self->ZONEMASTER_number_of_processes_for_batch_testing;

    my $timeout = $self->ZONEMASTER_max_zonemaster_execution_time;

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

sub _add_LANGUAGE_locale {
    my ( $self, $locale_tag ) = @_;

    $locale_tag = untaint_locale_tag( $locale_tag )    #
      // die "Illegal locale tag in LANGUAGE.locale: $locale_tag\n";

    my $lang_code = $locale_tag =~ s/_..$//r;

    if ( exists $self->{_LANGUAGE_locale}{$lang_code}{$locale_tag} ) {
        die "Repeated locale tags in LANGUAGE.locale: $locale_tag\n";
    }

    $self->{_LANGUAGE_locale}{$lang_code}{$locale_tag} = 1;

    return;
}

sub _reset_LANGUAGE_locale {
    my ( $self ) = @_;

    delete $self->{_LANGUAGE_locale};
    delete $self->{_LANGUAGE_default_locale};

    return;
}

sub _add_public_profile {
    my ( $self, $name, $path ) = @_;

    $name = untaint_profile_name( $name )    #
      // die "Invalid profile name in PUBLIC PROFILES section: $name\n";

    $name = lc $name;

    if ( defined $self->{_public_profiles}{$name} || exists $self->{_private_profiles}{$name} ) {
        die "Profile name not unique: $name\n";
    }

    if ( defined $path ) {
        $path = untaint_abs_path( $path )    #
          // die "Path must be absolute for profile: $name\n";
    }

    $self->{_public_profiles}{$name} = $path;
    return;
}

sub _add_private_profile {
    my ( $self, $name, $path ) = @_;

    $name = untaint_profile_name( $name )    #
      // die "Invalid profile name in PRIVATE PROFILES section: $name\n";

    $name = lc $name;

    if ( $name eq 'default' ) {
        die "Profile name must not be present in PRIVATE PROFILES section: $name\n";
    }

    if ( exists $self->{_public_profiles}{$name} || exists $self->{_private_profiles}{$name} ) {
        die "Profile name not unique: $name\n";
    }

    $path = untaint_abs_path( $path )    #
      // die "Path must be absolute for profile: $name\n";

    $self->{_private_profiles}{$name} = $path;
    return;
}

# Create a setter method with a given name using the given field and validator
sub _create_setter {
    my ( $setter, $field, $validate ) = @_;

    $setter =~ /^_set_([A-Z_]*)_([a-z_]*)$/
      or confess "Invalid setter name";
    my $section  = $1;
    my $property = $2;

    my $setter_impl = sub {
        my ( $self, $value ) = @_;

        $self->{$field} = $validate->( $value )    #
          // die "Invalid value for $section.$property: $value\n";

        return;
    };

    no strict 'refs';
    *$setter = $setter_impl;

    return;
}

sub _normalize_engine_type {
    my ( $value ) = @_;

    # Normalized to camel case to match the database engine Perl module name, e.g. "SQLite.pm".
    state $db_module_names = {
        mysql      => 'MySQL',
        postgresql => 'PostgreSQL',
        sqlite     => 'SQLite',
    };

    return $db_module_names->{ lc $value };
}

1;

package TestUtil;

use strict;
use warnings;

use Test::More;

use Zonemaster::Engine;
use Zonemaster::Backend::Config;

=head1 NAME

TestUtil - a set of methods to ease Zonemaster::Backend unit testing

=head1 SYNOPSIS

Because this package lies in the testing folder C<t/> and that folder is
unknown to the include path @INC, it can be including using the following code:

    my $t_path;
    BEGIN {
        use File::Spec::Functions qw( rel2abs );
        use File::Basename qw( dirname );
        $t_path = dirname( rel2abs( $0 ) );
    }
    use lib $t_path;
    use TestUtil;

Explicitely load any dependencies to Zonemaster::Backend::RPCAPI or
Zonemaster::Backend::TestAgent modules with

  use TestUtil qw( RPCAPI TestAgent );

=head1 ENVIRONMENT

=head2 TARGET

Set the database to use.
Can be C<SQLite>, C<MySQL> or C<PostgreSQL>.
Default to C<SQLite>.

=head2 ZONEMASTER_RECORD

If set, the data from the test is recorded to a file. Otherwise the data is
loaded from a file.

=cut

# Use the TARGET environment variable to set the database to use
# default to SQLite
my $db_backend = Zonemaster::Backend::Config->check_db( $ENV{TARGET} || 'SQLite' );
note "database: $db_backend";

sub import {
    my ( $class, @args ) = @_;
    if ( grep { $_ eq 'RPCAPI' } @args ) {
        require Zonemaster::Backend::RPCAPI;
        Zonemaster::Backend::RPCAPI->import();
    }
    if ( grep { $_ eq 'TestAgent' } @args ) {
        require Zonemaster::Backend::TestAgent;
        Zonemaster::Backend::TestAgent->import();
    }
}

sub db_backend {
    return $db_backend;
}

sub restore_datafile {
    my ( $datafile ) = @_;

    if ( not $ENV{ZONEMASTER_RECORD} ) {
        die q{Stored data file missing} if not -r $datafile;
        Zonemaster::Engine->preload_cache( $datafile );
        Zonemaster::Engine->profile->set( q{no_network}, 1 );
    } else {
        diag "recording";
    }
}

sub save_datafile {
    my ( $datafile ) = @_;

    if ( $ENV{ZONEMASTER_RECORD} ) {
        Zonemaster::Engine->save_cache( $datafile );
    }
}

sub prepare_db {
    my ( $db ) = @_;

    $db->drop_tables();
    $db->create_schema();
}

sub init_db {
    my ( $config ) = @_;

    my $dbclass = Zonemaster::Backend::DB->get_db_class( $db_backend );
    my $db      = $dbclass->from_config( $config );

    prepare_db( $db );

    return $db;
}

sub create_rpcapi {
    my ( $config ) = @_;

    my $rpcapi;
    eval {
        $rpcapi = Zonemaster::Backend::RPCAPI->new(
            {
                dbtype => $db_backend,
                config => $config,
            }
        );
    };
    if ( $@ ) {
        diag explain( $@ );
        BAIL_OUT( 'Could not connect to database' );
    }

    if ( not $rpcapi->isa('Zonemaster::Backend::RPCAPI' ) ) {
        BAIL_OUT( 'Not a Zonemaster::Backend::RPCAPI object' );
    }

    prepare_db( $rpcapi->{db} );

    return $rpcapi;
}

sub create_testagent {
    my ( $config ) = @_;

    my $agent = Zonemaster::Backend::TestAgent->new(
        {
            dbtype => "$db_backend",
            config => $config
        }
    );

    if ( not $agent->isa('Zonemaster::Backend::TestAgent' ) ) {
        BAIL_OUT( 'Not a Zonemaster::Backend::TestAgent object' );
    }

    return $agent;
}

=head1 METHODS

=over

=item db_backend()

Returns the name of the currently used database engine. This value is set via
the TARGET environment variable.

=item restore_datafile($datafile)

If the ZONEMASTER_RECORD environment variable is unset, the data from
C<$datafile> is used for all the current tests.

=item save_datafile($datafile)

If the ZONEMASTER_RECORD environment variable is set, the data from the current
tests are stored to C<$datafile>.

=item prepare_db($db)

Recreate all tables anew for the associated C<$db>.

=item init_db($config)

Returns a new Zonemaster::Backend::DB object using the provided C<$config>
file.

Database tables are dropped and created anew.

=item create_rpcapi($config)

Returns a new Zonemaster::Backend::RPCAPI object using the provided C<$config>
file.

Database tables are dropped and created anew.

=item create_testagent($config)

Returns a new Zonemaster::Backend::TestAgent object using the provided
C<$config> file.

=back

=cut

1;

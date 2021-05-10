#!perl -T
use strict;
use warnings;
use utf8;

use Test::More tests => 2;
use Test::NoWarnings;
use Scalar::Util qw( tainted );

# Get a tainted copy of a string
sub taint {
    my ( $string ) = @_;

    if ( !tainted $0 ) {
        BAIL_OUT( 'We need $0 to be tainted' );
    }

    return substr $string . $0, length $0;
}

subtest 'Everything but NoWarnings' => sub {

    use_ok( 'Zonemaster::Backend::Validator', ':untaint' );

    subtest 'untaint_engine_type' => sub {
        is scalar untaint_engine_type( 'MySQL' ),      'MySQL',      'accept: MySQL';
        is scalar untaint_engine_type( 'mysql' ),      'mysql',      'accept: mysql';
        is scalar untaint_engine_type( 'PostgreSQL' ), 'PostgreSQL', 'accept: PostgreSQL';
        is scalar untaint_engine_type( 'postgresql' ), 'postgresql', 'accept: postgresql';
        is scalar untaint_engine_type( 'SQLite' ),     'SQLite',     'accept: SQLite';
        is scalar untaint_engine_type( 'sqlite' ),     'sqlite',     'accept: sqlite';
        is scalar untaint_engine_type( 'Excel' ),      undef,        'reject: Excel';
        ok !tainted( untaint_engine_type( taint( 'SQLite' ) ) ), 'launder taint';
    };
};

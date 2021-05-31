#!perl -T
use strict;
use warnings;
use utf8;

use Test::More tests => 2;
use Test::NoWarnings;
use Test::Differences;
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

    subtest 'ds_info' => sub {
        my $v          = Zonemaster::Backend::Validator->new->ds_info;
        my $ds_info_40 = { digest => '0' x 40, algorithm => 0, digtype => 0, keytag => 0 };
        my $ds_info_64 = { digest => '0' x 64, algorithm => 0, digtype => 0, keytag => 0 };
        eq_or_diff [ $v->validate( $ds_info_40 ) ], [], 'accept ds_info with 40-digit hash';
        eq_or_diff [ $v->validate( $ds_info_64 ) ], [], 'accept ds_info with 64-digit hash';
    };

    subtest 'ip_address' => sub {
        my $v = Zonemaster::Backend::Validator->new->ip_address;
        eq_or_diff [ $v->validate( '192.168.0.2' ) ], [], 'accept: 192.168.0.2';
        eq_or_diff [ $v->validate( '2001:db8::1' ) ], [], 'accept: 2001:db8::1';
    };

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

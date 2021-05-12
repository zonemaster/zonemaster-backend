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

    subtest 'untaint_abs_path' => sub {
        is scalar untaint_abs_path( '/var/db/zonemaster.sqlite' ), '/var/db/zonemaster.sqlite', 'accept: /var/db/zonemaster.sqlite';
        is scalar untaint_abs_path( 'zonemaster.sqlite' ),         undef,                       'reject: zonemaster.sqlite';
        is scalar untaint_abs_path( './zonemaster.sqlite' ),       undef,                       'reject: ./zonemaster.sqlite';
        ok !tainted( untaint_abs_path( taint( 'localhost' ) ) ), 'launder taint';
    };

    subtest 'untaint_domain_name' => sub {
        is scalar untaint_domain_name( 'localhost' ),      'localhost',    'accept: localhost';
        is scalar untaint_domain_name( 'example.com' ),    'example.com',  'accept: example.com';
        is scalar untaint_domain_name( 'example.com.' ),   'example.com.', 'accept: example.com.';
        is scalar untaint_domain_name( '192.0.2.1' ),      '192.0.2.1',    'accept: 192.0.2.1';
        is scalar untaint_domain_name( '192.0.2.1:3306' ), undef,          'reject: 192.0.2.1:3306';
        ok !tainted( untaint_domain_name( taint( 'localhost' ) ) ), 'launder taint';
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

    subtest 'untaint_mariadb_database' => sub {
        is scalar untaint_mariadb_database( 'zonemaster' ),    'zonemaster',  'accept: zonemaster';
        is scalar untaint_mariadb_database( 'ZONEMASTER' ),    'ZONEMASTER',  'accept: ZONEMASTER';
        is scalar untaint_mariadb_database( 'dollar$' ),       'dollar$',     'accept: dollar$';
        is scalar untaint_mariadb_database( '$dollar' ),       '$dollar',     'accept: $dollar';
        is scalar untaint_mariadb_database( '0zonemaster' ),   '0zonemaster', 'accept: 0zonemaster';
        is scalar untaint_mariadb_database( 'zm_backend' ),    'zm_backend',  'accept: zm_backend';
        is scalar untaint_mariadb_database( 'zm backend' ),    undef,         'reject: zm backend';
        is scalar untaint_mariadb_database( 'zm-backend' ),    undef,         'reject: zm-backend';
        is scalar untaint_mariadb_database( '' ),              undef,         'reject empty string';
        is scalar untaint_mariadb_database( 'zönemästër' ), undef,         'reject: zönemästër';
        is scalar untaint_mariadb_database( 'a' x 65 ), undef, 'reject 65 characters';
        is scalar untaint_mariadb_database( 'a' x 64 ), 'a' x 64, 'accept 64 characters';
        ok !tainted( untaint_mariadb_database( taint( 'zonemaster' ) ) ), 'launder taint';
    };

    subtest 'untaint_mariadb_user' => sub {
        is scalar untaint_mariadb_user( 'zonemaster' ),    'zonemaster',  'accept: zonemaster';
        is scalar untaint_mariadb_user( 'ZONEMASTER' ),    'ZONEMASTER',  'accept: ZONEMASTER';
        is scalar untaint_mariadb_user( '$dollar' ),       '$dollar',     'accept: $dollar';
        is scalar untaint_mariadb_user( '0zonemaster' ),   '0zonemaster', 'accept: 0zonemaster';
        is scalar untaint_mariadb_user( 'zm_backend' ),    'zm_backend',  'accept: zm_backend';
        is scalar untaint_mariadb_user( 'zm backend' ),    undef,         'reject: zm backend';
        is scalar untaint_mariadb_user( 'zm-backend' ),    undef,         'reject: zm-backend';
        is scalar untaint_mariadb_user( '' ),              undef,         'reject empty string';
        is scalar untaint_mariadb_user( 'zönemästër' ), undef,         'reject: zönemästër';
        is scalar untaint_mariadb_user( 'a' x 81 ), undef, 'reject 81 characters';
        is scalar untaint_mariadb_user( 'a' x 80 ), 'a' x 80, 'accept 80 characters';
        ok !tainted( untaint_mariadb_user( taint( 'zonemaster' ) ) ), 'launder taint';
    };

    subtest 'untaint_password' => sub {
        is scalar untaint_password( '123456' ),         '123456',         'accept: 123456';
        is scalar untaint_password( 'password' ),       'password',       'accept: password';
        is scalar untaint_password( '!@#$%^&*<' ),      '!@#$%^&*<',      'accept: !@#$%^&*<';
        is scalar untaint_password( 'Qwertyuiop' ),     'Qwertyuiop',     'accept: Qwertyuiop';
        is scalar untaint_password( 'battery staple' ), 'battery staple', 'accept: battery staple';
        is scalar untaint_password( '' ),               '',               'accept the empty string';
        is scalar untaint_password( "\t" ),             undef,            'reject tab character';
        is scalar untaint_password( "\x80" ),           undef,            'reject del character';
        is scalar untaint_password( ' x' ),             undef,            'reject initial space';
        is scalar untaint_password( '<x' ),             undef,            'reject initial <';
        is scalar untaint_password( 'åäö' ),         undef,            'reject: åäö';
        is scalar untaint_password( 'a' x 100 ), 'a' x 100, 'accept 100 characters';
        is scalar untaint_password( 'a' x 101 ), undef, 'reject 101 characters';
        ok !tainted( untaint_password( taint( '123456' ) ) ), 'launder taint';
    };

    subtest 'untaint_positive_int' => sub {
        is scalar untaint_positive_int( '1' ),      '1',     'accept: 1';
        is scalar untaint_positive_int( '99999' ),  '99999', 'accept: 99999';
        is scalar untaint_positive_int( '100000' ), undef,   'reject: 100000';
        is scalar untaint_positive_int( '0' ),      undef,   'reject: 0';
        is scalar untaint_positive_int( '0.5' ),    undef,   'reject: 0.5';
        is scalar untaint_positive_int( '-1' ),     undef,   'reject: -1';
        ok !tainted( untaint_positive_int( taint( '1' ) ) ), 'launder taint';
    };

    subtest 'untaint_positive_millis' => sub {
        is scalar untaint_positive_millis( '0.5' ),       '0.5',       'accept: 0.5';
        is scalar untaint_positive_millis( '0.001' ),     '0.001',     'accept: 0.001';
        is scalar untaint_positive_millis( '99999.999' ), '99999.999', 'accept: 99999.999';
        is scalar untaint_positive_millis( '1' ),         '1',         'accept: 1';
        is scalar untaint_positive_millis( '99999' ),     '99999',     'accept: 99999';
        is scalar untaint_positive_millis( '0.0009' ),    undef,       'reject: 0.0009';
        is scalar untaint_positive_millis( '100000' ),    undef,       'reject: 100000';
        is scalar untaint_positive_millis( '0' ),         undef,       'reject: 0';
        is scalar untaint_positive_millis( '0.0' ),       undef,       'reject: 0.0';
        is scalar untaint_positive_millis( '-1' ),        undef,       'reject: -1';
        ok !tainted( untaint_positive_millis( taint( '0.5' ) ) ), 'launder taint';
    };

    subtest 'untaint_postgresql_ident' => sub {
        is scalar untaint_postgresql_ident( 'zonemaster' ),    'zonemaster', 'accept: zonemaster';
        is scalar untaint_postgresql_ident( 'ZONEMASTER' ),    'ZONEMASTER', 'accept: ZONEMASTER';
        is scalar untaint_postgresql_ident( 'zm_backend' ),    'zm_backend', 'accept: zm_backend';
        is scalar untaint_postgresql_ident( 'dollar$' ),       'dollar$',    'accept: dollar$';
        is scalar untaint_postgresql_ident( '$dollar' ),       undef,        'reject: $dollar';
        is scalar untaint_postgresql_ident( 'zm backend' ),    undef,        'reject: zm backend';
        is scalar untaint_postgresql_ident( '0zonemaster' ),   undef,        'reject: 0zonemaster';
        is scalar untaint_postgresql_ident( 'zm-backend' ),    undef,        'reject: zm-backend';
        is scalar untaint_postgresql_ident( '' ),              undef,        'reject empty string';
        is scalar untaint_postgresql_ident( 'zönemästër' ), undef,        'reject: zönemästër';
        is scalar untaint_postgresql_ident( 'a' x 64 ), undef, 'reject 64 characters';
        is scalar untaint_postgresql_ident( 'a' x 63 ), 'a' x 63, 'accept 63 characters';
        ok !tainted( untaint_postgresql_ident( taint( 'zonemaster' ) ) ), 'launder taint';
    };

    subtest 'untaint_unsigned_int' => sub {
        is scalar untaint_unsigned_int( '1' ),      '1',     'accept: 1';
        is scalar untaint_unsigned_int( '0' ),      '0',     'accept: 0';
        is scalar untaint_unsigned_int( '99999' ),  '99999', 'accept: 99999';
        is scalar untaint_unsigned_int( '100000' ), undef,   'reject: 100000';
        is scalar untaint_unsigned_int( '0.5' ),    undef,   'reject: 0.5';
        is scalar untaint_unsigned_int( '-1' ),     undef,   'reject: -1';
        ok !tainted( untaint_unsigned_int( taint( '1' ) ) ), 'launder taint';
    };
};

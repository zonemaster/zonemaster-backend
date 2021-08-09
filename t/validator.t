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

    subtest 'untaint_ip_address' => sub {
        is scalar untaint_ip_address( '192.0.2.1' ),                              '192.0.2.1',                              'accept: 192.0.2.1';
        is scalar untaint_ip_address( '192.0.2' ),                                undef,                                    'reject: 192.0.2';
        is scalar untaint_ip_address( '192' ),                                    undef,                                    'reject: 192';
        is scalar untaint_ip_address( '192.0.2.1:3306' ),                         undef,                                    'reject: 192.0.2.1:3306';
        is scalar untaint_ip_address( '2001:db8::' ),                             '2001:db8::',                             'accept: 2001:db8::';
        is scalar untaint_ip_address( '2001:db8::/32' ),                          undef,                                    'reject: 2001:db8::/32';
        is scalar untaint_ip_address( '2001:db8:ffff:ffff:ffff:ffff:ffff:ffff' ), '2001:db8:ffff:ffff:ffff:ffff:ffff:ffff', 'accept: 2001:db8:ffff:ffff:ffff:ffff:ffff:ffff';
        is scalar untaint_ip_address( '2001:db8:ffff:ffff:ffff:ffff:ffff' ),      undef,                                    'reject: 2001:db8:ffff:ffff:ffff:ffff:ffff';
        is scalar untaint_ip_address( '2001:db8::255.255.255.254' ),              '2001:db8::255.255.255.254',              'accept: 2001:db8::255.255.255.254';
        is scalar untaint_ip_address( '2001:db8::255.255.255' ),                  undef,                                    'reject: 2001:db8::255.255.255';
        is scalar untaint_ip_address( '::1' ),                                    '::1',                                    'accept: ::1';
        is scalar untaint_ip_address( ':::1' ),                                   undef,                                    'reject: :::1';
        ok !tainted( untaint_ip_address( taint( '192.0.2.1' ) ) ), 'launder taint';
    };

    subtest 'untaint_ldh_domain' => sub {
        is scalar untaint_ldh_domain( 'localhost' ),                 'localhost',    'accept: localhost';
        is scalar untaint_ldh_domain( 'example.com' ),               'example.com',  'accept: example.com';
        is scalar untaint_ldh_domain( 'example.com.' ),              'example.com.', 'accept: example.com.';
        is scalar untaint_ldh_domain( '192.0.2.1' ),                 '192.0.2.1',    'accept: 192.0.2.1';
        is scalar untaint_ldh_domain( '192.0.2.1:3306' ),            undef,          'reject: 192.0.2.1:3306';
        is scalar untaint_ldh_domain( '1/26.2.0.192.in-addr.arpa' ), undef,          'reject: 1/26.2.0.192.in-addr.arpa';
        is scalar untaint_ldh_domain( '_http.example.com' ),         undef,          'reject: _http.example.com';
        ok !tainted( untaint_ldh_domain( taint( 'localhost' ) ) ), 'launder taint';
    };

    subtest 'untaint_locale_tag' => sub {
        is scalar untaint_locale_tag( 'en_US' ),   'en_US', 'accept: en_US';
        is scalar untaint_locale_tag( 'en' ),      undef,   'reject: en';
        is scalar untaint_locale_tag( 'English' ), undef,   'reject: English';
        ok !tainted( untaint_locale_tag( taint( 'en_US' ) ) ), 'launder taint';
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

    subtest 'untaint_profile_name' => sub {
        is scalar untaint_profile_name( 'default' ),              'default',           'accept: default';
        is scalar untaint_profile_name( '-leading-dash' ),        undef,               'reject: -leading-dash';
        is scalar untaint_profile_name( 'trailing-dash-' ),       undef,               'reject: trailing-dash-';
        is scalar untaint_profile_name( 'middle-dash' ),          'middle-dash',       'accept: middle-dash';
        is scalar untaint_profile_name( '_leading_underscore' ),  undef,               'reject: _leading_underscore';
        is scalar untaint_profile_name( 'trailing_underscore_' ), undef,               'reject: trailing_underscore_';
        is scalar untaint_profile_name( 'middle_underscore' ),    'middle_underscore', 'accept: middle_underscore';
        is scalar untaint_profile_name( '0-leading-digit' ),      '0-leading-digit',   'accept: 0-leading-digit';
        is scalar untaint_profile_name( 'a' ),                    'a',                 'accept: a';
        is scalar untaint_profile_name( '-' ),                    undef,               'reject dash';
        is scalar untaint_profile_name( '_' ),                    undef,               'reject underscore';
        is scalar untaint_profile_name( 'a' x 32 ), 'a' x 32, 'accept 32 characters';
        is scalar untaint_profile_name( 'a' x 33 ), undef, 'reject 33 characters';
        ok !tainted( untaint_profile_name( taint( 'default' ) ) ), 'launder taint';
    };

    subtest 'untaint_non_negative_int' => sub {
        is scalar untaint_non_negative_int( '1' ),      '1',     'accept: 1';
        is scalar untaint_non_negative_int( '0' ),      '0',     'accept: 0';
        is scalar untaint_non_negative_int( '99999' ),  '99999', 'accept: 99999';
        is scalar untaint_non_negative_int( '100000' ), undef,   'reject: 100000';
        is scalar untaint_non_negative_int( '0.5' ),    undef,   'reject: 0.5';
        is scalar untaint_non_negative_int( '-1' ),     undef,   'reject: -1';
        ok !tainted( untaint_non_negative_int( taint( '1' ) ) ), 'launder taint';
    };

    subtest 'untaint_strictly_positive_int' => sub {
        is scalar untaint_strictly_positive_int( '1' ),      '1',     'accept: 1';
        is scalar untaint_strictly_positive_int( '99999' ),  '99999', 'accept: 99999';
        is scalar untaint_strictly_positive_int( '100000' ), undef,   'reject: 100000';
        is scalar untaint_strictly_positive_int( '0' ),      undef,   'reject: 0';
        is scalar untaint_strictly_positive_int( '0.5' ),    undef,   'reject: 0.5';
        is scalar untaint_strictly_positive_int( '-1' ),     undef,   'reject: -1';
        ok !tainted( untaint_strictly_positive_int( taint( '1' ) ) ), 'launder taint';
    };

    subtest 'untaint_strictly_positive_millis' => sub {
        is scalar untaint_strictly_positive_millis( '0.5' ),       '0.5',       'accept: 0.5';
        is scalar untaint_strictly_positive_millis( '0.001' ),     '0.001',     'accept: 0.001';
        is scalar untaint_strictly_positive_millis( '99999.999' ), '99999.999', 'accept: 99999.999';
        is scalar untaint_strictly_positive_millis( '1' ),         '1',         'accept: 1';
        is scalar untaint_strictly_positive_millis( '99999' ),     '99999',     'accept: 99999';
        is scalar untaint_strictly_positive_millis( '0.0009' ),    undef,       'reject: 0.0009';
        is scalar untaint_strictly_positive_millis( '100000' ),    undef,       'reject: 100000';
        is scalar untaint_strictly_positive_millis( '0' ),         undef,       'reject: 0';
        is scalar untaint_strictly_positive_millis( '0.0' ),       undef,       'reject: 0.0';
        is scalar untaint_strictly_positive_millis( '-1' ),        undef,       'reject: -1';
        ok !tainted( untaint_strictly_positive_millis( taint( '0.5' ) ) ), 'launder taint';
    };
};

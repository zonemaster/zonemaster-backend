use strict;
use warnings;
use 5.14.2;
use utf8;

use Test::More tests => 2;
use Test::NoWarnings;

use Encode;
use File::ShareDir qw[dist_file];
use JSON::PP;
use File::Temp qw[tempdir];
use Zonemaster::Backend::Config;
use Zonemaster::Backend::RPCAPI;

my $tempdir = tempdir( CLEANUP => 1 );

my $config = Zonemaster::Backend::Config->parse( <<EOF );
[DB]
engine = SQLite

[SQLITE]
database_file = $tempdir/zonemaster.sqlite

[LANGUAGE]
locale = en_US fr_FR da_DK fi_FI nb_NO sv_SE
EOF

my $engine = Zonemaster::Backend::RPCAPI->new(
    {
        dbtype => $config->DB_engine,
        config => $config,
    }
);

subtest 'Everything but NoWarnings' => sub {

    my $can_use_threads = eval 'use threads; 1';

    my $frontend_params = {
        ipv4 => 1,
        ipv6 => 1,
    };

    $frontend_params->{nameservers} = [    # list of the namaserves up to 32
        { ns => 'ns1.nic.fr', ip => '1.2.3.4' },       # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ];

    subtest 'domain present' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => 'afnic.fr'
            }
        );

        is( $res->{status}, 'ok' );
    };

    subtest encode_utf8( 'idn domain=[é]' ) => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => 'é'
            }
        );

        is( $res->{status}, 'ok' )
            or diag( $res->{message} );
    };

    subtest encode_utf8( 'idn domain=[éé]' ) => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => 'éé'
            }
        );

        is( $res->{status}, 'ok' )
            or diag( $res->{message} );
    };

    subtest '253 characters long domain without dot' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com'
            }
        );

        is(
            $res->{status}, 'ok'
        ) or diag( $res->{message} );
    };

    subtest '254 characters long domain with trailing dot' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com.'
            }
        );

        is(
            $res->{status}, 'ok'
        ) or diag( $res->{message} );
    };

    subtest '254 characters long domain without trailing dot' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.club'
            }
        );

        is(
            $res->{status}, 'nok'
        ) or diag( $res->{message} );
    };

    subtest '63 characters long domain label' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => '012345678901234567890123456789012345678901234567890123456789-63.fr'
            }
        );

        is( $res->{status}, 'ok' )
            or diag( $res->{message} );
    };

    subtest '64 characters long domain label' => sub {
        my $res = $engine->start_domain_test_validate_syntax(
            {
                %$frontend_params, domain => '012345678901234567890123456789012345678901234567890123456789--64.fr'
            }
        );

        is( $res->{status}, 'nok')
            or diag( $res->{message} );
    };

    #TEST NS
    $frontend_params->{domain} = 'afnic.fr';
    $frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';

    # domain present?
    $frontend_params->{nameservers}->[0]->{ns} = 'afnic.fr';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', 'domain present' );

    # idn
    $frontend_params->{nameservers}->[0]->{ns} = 'é';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', encode_utf8( 'idn domain=[é]' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # idn
    $frontend_params->{nameservers}->[0]->{ns} = 'éé';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', encode_utf8( 'idn domain=[éé]' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # 253 characters long domain without dot
    $frontend_params->{nameservers}->[0]->{ns} =
    '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com';
    is(
        $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok',
        encode_utf8( '253 characters long domain without dot' )
    ) or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # 254 characters long domain with trailing dot
    $frontend_params->{nameservers}->[0]->{ns} =
    '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com.';
    is(
        $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok',
        encode_utf8( '254 characters long domain with trailing dot' )
    ) or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # 254 characters long domain without trailing
    $frontend_params->{nameservers}->[0]->{ns} =
    '123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.club';
    is(
        $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'nok',
        encode_utf8( '254 characters long domain without trailing dot' )
    ) or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # 63 characters long domain label
    $frontend_params->{nameservers}->[0]->{ns} = '012345678901234567890123456789012345678901234567890123456789-63.fr';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok',
        encode_utf8( '63 characters long domain label' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # 64 characters long domain label
    $frontend_params->{nameservers}->[0]->{ns} = '012345678901234567890123456789012345678901234567890123456789-64-.fr';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'nok',
        encode_utf8( '64 characters long domain label' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # DELEGATED TEST
    delete( $frontend_params->{nameservers} );

    $frontend_params->{domain} = 'afnic.fr';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', encode_utf8( 'delegated domain exists' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # IP ADDRESS FORMAT
    $frontend_params->{domain} = 'afnic.fr';
    $frontend_params->{nameservers}->[0]->{ns} = 'ns1.nic.fr';

    $frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', encode_utf8( 'Valid IPV4' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    $frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4444';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'nok', encode_utf8( 'Invalid IPV4' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    $frontend_params->{nameservers}->[0]->{ip} = 'fe80::6ef0:49ff:fe7b:e4bb';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'ok', encode_utf8( 'Valid IPV6' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    $frontend_params->{nameservers}->[0]->{ip} = 'fe80::6ef0:49ff:fe7b:e4bbffffff';
    is( $engine->start_domain_test_validate_syntax( $frontend_params )->{status}, 'nok', encode_utf8( 'Invalid IPV6' ) )
        or diag( $engine->start_domain_test_validate_syntax( $frontend_params )->{message} );

    # DS
    $frontend_params->{domain}                 = 'afnic.fr';
    $frontend_params->{nameservers}->[0]->{ns} = 'ns1.nic.fr';
    $frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';

    $frontend_params->{ds_info}->[0]->{algorithm} = 1;
    $frontend_params->{ds_info}->[0]->{digest}    = '0123456789012345678901234567890123456789';
    $frontend_params->{ds_info}->[0]->{digtype}   = 1;
    $frontend_params->{ds_info}->[0]->{keytag}   = 5000;

    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 0, encode_utf8( 'Valid Algorithm Type [numeric format]' ) )
        or diag( encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{ds_info}->[0]->{algorithm} = 'a';
    $frontend_params->{ds_info}->[0]->{digest}    = '0123456789012345678901234567890123456789';
    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 1, encode_utf8( 'Invalid Algorithm Type' ) )
        or diag(  encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{ds_info}->[0]->{algorithm} = 1;
    $frontend_params->{ds_info}->[0]->{digest}    = '01234567890123456789012345678901234567890';
    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 1, encode_utf8( 'Invalid digest length' ) )
        or diag( encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{ds_info}->[0]->{algorithm} = 1;
    $frontend_params->{ds_info}->[0]->{digest}    = 'Z123456789012345678901234567890123456789';
    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 1, encode_utf8( 'Invalid digest format' ) )
        or diag(  encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{ds_info}->[0]->{digest}    = '0123456789012345678901234567890123456789';
    $frontend_params->{language} = "zz";
    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 1, encode_utf8( 'Invalid language, "zz" unknown' ) )
        or diag(  encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{language} = "fr-FR";
    cmp_ok( @{$engine->validate_params( "start_domain_test", $frontend_params )}, ">", 0, encode_utf8( 'Invalid language, should be underscore not hyphen' ) )
        or diag(  encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );

    $frontend_params->{language} = "nb_NO";
    is( @{$engine->validate_params( "start_domain_test", $frontend_params )}, 0, encode_utf8( 'Valid language' ) )
        or diag(  encode_json $engine->validate_params( "start_domain_test", $frontend_params ) );
};

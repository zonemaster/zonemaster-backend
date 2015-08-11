use strict;
use warnings;
use 5.14.2;
use utf8;

use Encode;
use Test::More;    # see done_testing()

my $can_use_threads = eval 'use threads; 1';

# Require Zonemaster::WebBackend::Engine.pm test
use_ok( 'Zonemaster::WebBackend::Engine' );

# Create Zonemaster::WebBackend::Engine object
my $engine = Zonemaster::WebBackend::Engine->new( { db => 'Zonemaster::WebBackend::DB::SQLite' } );
isa_ok( $engine, 'Zonemaster::WebBackend::Engine' );

my $frontend_params = {
	ipv4 => 1,
	ipv6 => 1,
};

$frontend_params->{nameservers} = [    # list of the namaserves up to 32
	{ ns => 'ns1.nic.fr', ip => '1.2.3.4' },       # key values pairs representing nameserver => namesterver_ip
	{ ns => 'ns2.nic.fr', ip => '192.134.4.1' },
];

# domain present?
$frontend_params->{domain} = '';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', 'domain not present' );

# domain present?
$frontend_params->{domain} = 'afnic.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', 'domain present' );

# idn
$frontend_params->{domain} = 'é';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'idn domain=[é]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# idn
$frontend_params->{domain} = 'éé';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'idn domain=[éé]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 253 characters long domain without dot
$frontend_params->{domain} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '253 characters long domain without dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 254 characters long domain with trailing dot
$frontend_params->{domain} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com.';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '254 characters long domain with trailing dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 254 characters long domain without trailing
$frontend_params->{domain} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.club';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( '254 characters long domain without trailing dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 63 characters long domain label
$frontend_params->{domain} = '012345678901234567890123456789012345678901234567890123456789-63.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '63 characters long domain label' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 64 characters long domain label
$frontend_params->{domain} = '012345678901234567890123456789012345678901234567890123456789-64-.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( '64 characters long domain label' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# invalid domain characters
$frontend_params->{domain} = 'test1_.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'invalid domain characters' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

#TEST NS
$frontend_params->{domain} = 'afnic.fr';
$frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';

# ns present?
$frontend_params->{nameservers}->[0]->{ns} = '';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', 'domain not present' );

# domain present?
$frontend_params->{nameservers}->[0]->{ns} = 'afnic.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', 'domain present' );

# idn
$frontend_params->{nameservers}->[0]->{ns} = 'é';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'idn domain=[é]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# idn
$frontend_params->{nameservers}->[0]->{ns} = 'éé';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'idn domain=[éé]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 253 characters long domain without dot
$frontend_params->{nameservers}->[0]->{ns} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '253 characters long domain without dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 254 characters long domain with trailing dot
$frontend_params->{nameservers}->[0]->{ns} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.com.';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '254 characters long domain with trailing dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 254 characters long domain without trailing
$frontend_params->{nameservers}->[0]->{ns} =
'123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.club';
ok(
	$engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( '254 characters long domain without trailing dot' )
) or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 63 characters long domain label
$frontend_params->{nameservers}->[0]->{ns} = '012345678901234567890123456789012345678901234567890123456789-63.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok',
	encode_utf8( '63 characters long domain label' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# 64 characters long domain label
$frontend_params->{nameservers}->[0]->{ns} = '012345678901234567890123456789012345678901234567890123456789-64-.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( '64 characters long domain label' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# invalid domain characters
$frontend_params->{nameservers}->[0]->{ns} = 'test1_.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'invalid domain characters' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# DELEGATED TEST
delete( $frontend_params->{nameservers} );

$frontend_params->{domain} = 'afnic.fr';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'delegated domain exists' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# IP ADDRESS FORMAT
$frontend_params->{domain} = 'afnic.fr';
$frontend_params->{nameservers}->[0]->{ns} = 'ns1.nic.fr';

$frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'Valid IPV4' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4444';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'Invalid IPV4' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{nameservers}->[0]->{ip} = 'fe80::6ef0:49ff:fe7b:e4bb';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'Valid IPV6' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{nameservers}->[0]->{ip} = 'fe80::6ef0:49ff:fe7b:e4bbffffff';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'Invalid IPV6' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

# DS
$frontend_params->{domain}                 = 'afnic.fr';
$frontend_params->{nameservers}->[0]->{ns} = 'ns1.nic.fr';
$frontend_params->{nameservers}->[0]->{ip} = '1.2.3.4';

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha1';
$frontend_params->{ds_digest_pairs}->[0]->{digest}    = '0123456789012345678901234567890123456789';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'Valid Algorithm Type [sha1]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha256';
$frontend_params->{ds_digest_pairs}->[0]->{digest} =
	'0123456789012345678901234567890123456789012345678901234567890123';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'ok', encode_utf8( 'Valid Algorithm Type [sha256]' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha2';
$frontend_params->{ds_digest_pairs}->[0]->{digest}    = '0123456789012345678901234567890123456789';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'Invalid Algorithm Type' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha1';
$frontend_params->{ds_digest_pairs}->[0]->{digest}    = '01234567890123456789012345678901234567890';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'Invalid [sha1] digest length' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha256';
$frontend_params->{ds_digest_pairs}->[0]->{digest} =
	'01234567890123456789012345678901234567890123456789012345678901230';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( 'Invalid [sha256] digest length' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha1';
$frontend_params->{ds_digest_pairs}->[0]->{digest}    = 'Z123456789012345678901234567890123456789';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok', encode_utf8( 'Invalid [sha1] digest format' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

$frontend_params->{ds_digest_pairs}->[0]->{algorithm} = 'sha256';
$frontend_params->{ds_digest_pairs}->[0]->{digest} =
	'Z123456789012345678901234567890123456789012345678901234567890123';
ok( $engine->validate_syntax( $frontend_params )->{status} eq 'nok',
	encode_utf8( 'Invalid [sha256] digest fprmat' ) )
	or diag( $engine->validate_syntax( $frontend_params )->{message} );

done_testing();

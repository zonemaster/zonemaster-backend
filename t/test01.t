use strict;
use warnings;
use 5.14.2;

use Test::More;    # see done_testing()
use Zonemaster;

my $datafile = q{t/test01.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster->preload_cache( $datafile );
    Zonemaster->config->no_network( 1 );
}

# Require Zonemaster::WebBackend::Engine.pm test
use_ok( 'Zonemaster::WebBackend::Engine' );

# Create Zonemaster::WebBackend::Engine object
my $engine = Zonemaster::WebBackend::Engine->new( { db => 'Zonemaster::WebBackend::DB::SQLite' } );
isa_ok( $engine, 'Zonemaster::WebBackend::Engine' );

# create a new memory SQLite database
ok( $engine->{db}->create_db() );

# add test user
ok( $engine->add_api_user( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } ) == 1 );
ok(
    scalar( $engine->{db}->dbh->selectrow_array( q/SELECT * FROM users WHERE user_info like '%zonemaster_test%'/ ) ) ==
      1 );

# add a new test to the db
my $frontend_params_1 = {
    client_id      => 'Unit Test',         # free string
    client_version => '1.0',               # free version like string
    domain         => 'afnic.fr',          # content of the domain text field
    advanced       => 1,                   # 0 or 1, is the advanced options checkbox checked
    ipv4           => 1,                   # 0 or 1, is the ipv4 checkbox checked
    ipv6           => 1,                   # 0 or 1, is the ipv6 checkbox checked
    profile        => 'test_profile_1',    # the id if the Test profile listbox

    nameservers => [                       # list of the nameserves up to 32
        { ns => 'ns1.nic.fr', ip => '1.1.1.1' },       # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ],
    ds_digest_pairs => [                               # list of DS/Digest pairs up to 32
        { algorithm => 'sha1', digest => '0123456789012345678901234567890123456789' }
        ,                                              # key values pairs representing ds => digest
        { algorithm => 'sha256', digest => '0123456789012345678901234567890123456789012345678901234567890123' }
        ,                                              # key values pairs representing ds => digest
    ],
};
ok( $engine->start_domain_test( $frontend_params_1 ) == 1 );
ok( scalar( $engine->{db}->dbh->selectrow_array( q/SELECT id FROM test_results WHERE id=1/ ) ) == 1 );

# test test_progress API
ok( $engine->test_progress( 1 ) == 0 );

use_ok( 'Zonemaster::WebBackend::Runner' );
Zonemaster::WebBackend::Runner->new( { db => "Zonemaster::WebBackend::DB::SQLite" } )->run( 1 );

ok( $engine->test_progress( 1 ) > 0 );

foreach my $i ( 1 .. 12 ) {
    my $progress = $engine->test_progress( 1 );
    last if ( $progress == 100 );
}
ok( $engine->test_progress( 1 ) == 100 );
my $test_results = $engine->get_test_results( { id => 1, language => 'fr-FR' } );
ok( defined $test_results->{id},                 'TEST1 $test_results->{id} defined' );
ok( defined $test_results->{params},             'TEST1 $test_results->{params} defined' );
ok( defined $test_results->{creation_time},      'TEST1 $test_results->{creation_time} defined' );
ok( defined $test_results->{results},            'TEST1 $test_results->{results} defined' );
ok( scalar( @{ $test_results->{results} } ) > 1, 'TEST1 got some results' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster->save_cache( $datafile );
}

my $dbfile = 'zonemaster';
if ( -e $dbfile and -M $dbfile < 0 and -o $dbfile ) {
    unlink $dbfile;
}

done_testing();

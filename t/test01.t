use strict;
use warnings;
use 5.14.2;

use Test::More;    # see done_testing()
use Zonemaster::Engine;
use JSON::PP;

my $datafile = q{t/test01.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine->preload_cache( $datafile );
	Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

# Require Zonemaster::Backend::RPCAPI.pm test
use_ok( 'Zonemaster::Backend::RPCAPI' );

my $config = Zonemaster::Backend::Config->load_config();

# Create Zonemaster::Backend::RPCAPI object
my $engine = Zonemaster::Backend::RPCAPI->new(
    {
        db     => 'Zonemaster::Backend::DB::SQLite',
        config => $config,
    }
);
isa_ok( $engine, 'Zonemaster::Backend::RPCAPI' );

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
    ipv4           => JSON::PP::true,                   # 0 or 1, is the ipv4 checkbox checked
    ipv6           => JSON::PP::true,                   # 0 or 1, is the ipv6 checkbox checked
    profile        => 'default',    # the id if the Test profile listbox

    nameservers => [                       # list of the nameserves up to 32
        { ns => 'ns1.nic.fr' },       # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ],
    ds_info => [                                  # list of DS/Digest pairs up to 32
        { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
    ],
};

sub run_zonemaster_test_with_backend_API {
	my ($test_id) = @_;
	
	ok( $engine->start_domain_test( $frontend_params_1 ) == $test_id, "API start_domain_test OK/test_id=$test_id" );
	ok( scalar( $engine->{db}->dbh->selectrow_array( qq/SELECT id FROM test_results WHERE id=$test_id/ ) ) == $test_id );

	# test test_progress API
	ok( $engine->test_progress( $test_id ) == 0 );

	use_ok( 'Zonemaster::Backend::Config' );

	use_ok( 'Zonemaster::Backend::TestAgent' );

	if ( not $ENV{ZONEMASTER_RECORD} ) {
		Zonemaster::Engine->preload_cache( $datafile );
		Zonemaster::Engine->profile->set( q{no_network}, 1 );
	}
	Zonemaster::Backend::TestAgent->new( { db => "Zonemaster::Backend::DB::SQLite", config => $config } )->run( $test_id );

	Zonemaster::Backend::TestAgent->reset() unless ( $ENV{ZONEMASTER_RECORD} );

	ok( $engine->test_progress( $test_id ) > 0 );

	foreach my $i ( 1 .. 12 ) {
		my $progress = $engine->test_progress( $test_id );
		last if ( $progress == 100 );
	}
	ok( $engine->test_progress( $test_id ) == 100 );
	my $test_results = $engine->get_test_results( { id => $test_id, language => 'fr-FR' } );
	ok( defined $test_results->{id},                 'TEST1 $test_results->{id} defined' );
	ok( defined $test_results->{params},             'TEST1 $test_results->{params} defined' );
	ok( defined $test_results->{creation_time},      'TEST1 $test_results->{creation_time} defined' );
	ok( defined $test_results->{results},            'TEST1 $test_results->{results} defined' );
	ok( scalar( @{ $test_results->{results} } ) > 1, 'TEST1 got some results' );

}

run_zonemaster_test_with_backend_API(1);
$frontend_params_1->{ipv6} = 0;
run_zonemaster_test_with_backend_API(2);

if ( $ENV{ZONEMASTER_RECORD} ) {
	Zonemaster::Engine->save_cache( $datafile );
}
done_testing();

my $dbfile = 'zonemaster';
if ( -e $dbfile and -M $dbfile < 0 and -o $dbfile ) {
	unlink $dbfile;
}

use strict;
use warnings;
use 5.14.2;

use Test::More;    # see done_testing()

my $can_use_pg = eval 'use DBD::Pg; 1';

my $frontend_params_1 = {
	client_id      => 'PostgreSQL Unit Test',         # free string
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

use_ok( 'Zonemaster::WebBackend::Engine' );
# Create Zonemaster::WebBackend::Engine object
my $engine = Zonemaster::WebBackend::Engine->new( { db => 'Zonemaster::WebBackend::DB::PostgreSQL' } );
isa_ok( $engine, 'Zonemaster::WebBackend::Engine' );

sub run_zonemaster_test_with_backend_API {
	my ($test_id) = @_;
    # add a new test to the db
    
    ok( $engine->start_domain_test( $frontend_params_1 ) == $test_id , 'API start_domain_test -> Call OK' );
    ok( scalar( $engine->{db}->dbh->selectrow_array( qq/SELECT id FROM test_results WHERE id=$test_id/ ) ) == $test_id , 'API start_domain_test -> Test inserted in the DB' );

    # test test_progress API
    ok( $engine->test_progress( $test_id ) == 0 , 'API test_progress -> OK');

    use_ok( 'Zonemaster::WebBackend::Runner' );
	Zonemaster::WebBackend::Runner->new( { db => 'Zonemaster::WebBackend::DB::PostgreSQL' } )->run( $test_id );

    sleep( 5 );
    ok( $engine->test_progress( $test_id ) > 0 , 'API test_progress -> Test started');

    foreach my $i ( 1 .. 12 ) {
        sleep( 5 );
        my $progress = $engine->test_progress( $test_id );
        diag "pregress: $progress";
        last if ( $progress == 100 );
    }
    ok( $engine->test_progress( $test_id ) == 100 , 'API test_progress -> Test finished' );
    my $test_results = $engine->get_test_results( { id => $test_id, language => 'fr-FR' } );
    ok( defined $test_results->{id} , 'API get_test_results -> [id] paramater present' );
    ok( defined $test_results->{params} , 'API get_test_results -> [params] paramater present' );
    ok( defined $test_results->{creation_time} , 'API get_test_results -> [creation_time] paramater present' );
    ok( defined $test_results->{results} , 'API get_test_results -> [results] paramater present' );
    ok( scalar( @{ $test_results->{results} } ) > 1 , 'API get_test_results -> [results] paramater contains data' );
}

if ( not $can_use_pg) {
    plan skip_all => 'Could not load DBD::Pg.';
}
else {

    # add test user
    ok( $engine->add_api_user( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } ) == 1, 'API add_api_user OK' );
    ok(
        scalar(
            $engine->{db}
              ->dbh->selectrow_array( q/SELECT * FROM users WHERE user_info->>'username' = 'zonemaster_test'/ )
        ) == 1
    , 'API add_api_user user created' );

	run_zonemaster_test_with_backend_API(1);
	$frontend_params_1->{ipv6} = 0;
	run_zonemaster_test_with_backend_API(2);

    my $offset = 0;
    my $limit  = 10;
    my $test_history =
      $engine->get_test_history( { frontend_params => $frontend_params_1, offset => $offset, limit => $limit } );
    diag explain( $test_history );
    ok( scalar( @$test_history ) == 2 );
    ok( $test_history->[0]->{id} == 1 || $test_history->[1]->{id} == 1 );
    ok( $test_history->[0]->{id} == 2 || $test_history->[1]->{id} == 2 );

    done_testing();
}

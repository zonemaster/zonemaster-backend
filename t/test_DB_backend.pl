use strict;
use warnings;
use 5.14.2;

use Test::More;    # see done_testing()
use JSON::PP;

my $db_backend = $ARGV[0];
ok( $db_backend eq 'PostgreSQL' || $db_backend eq 'MySQL' , "Testing a supported database backend: $db_backend" );

my $frontend_params_1 = {
	client_id      => "$db_backend Unit Test",         # free string
	client_version => '1.0',               # free version like string
	domain         => 'afnic.fr',          # content of the domain text field
	ipv4           => JSON::PP::true,                   # 0 or 1, is the ipv4 checkbox checked
	ipv6           => JSON::PP::true,                   # 0 or 1, is the ipv6 checkbox checked
	profile        => 'default',    # the id if the Test profile listbox

	nameservers => [                       # list of the nameserves up to 32
		{ ns => 'ns1.nic.fr', ip => '1.1.1.1' },       # key values pairs representing nameserver => namesterver_ip
		{ ns => 'ns2.nic.fr', ip => '192.134.4.1' },
	],
    ds_info => [                                  # list of DS/Digest pairs up to 32
        { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
    ],
};

use_ok( 'Zonemaster::Backend::RPCAPI' );
# Create Zonemaster::Backend::RPCAPI object
my $engine = Zonemaster::Backend::RPCAPI->new( { db => "Zonemaster::Backend::DB::$db_backend" } );
isa_ok( $engine, 'Zonemaster::Backend::RPCAPI' );

sub run_zonemaster_test_with_backend_API {
	my ($test_id) = @_;
    # add a new test to the db
    
    my $api_test_id = $engine->start_domain_test( $frontend_params_1 );
    ok( $api_test_id eq $test_id || length($api_test_id) == 16 , 'API start_domain_test -> Call OK' );
    ok( scalar( $engine->{db}->dbh->selectrow_array( qq/SELECT id FROM test_results WHERE id=$test_id/ ) ) eq $test_id , 'API start_domain_test -> Test inserted in the DB' );
    my $hash_id = $engine->{db}->dbh->selectrow_array( qq/SELECT hash_id FROM test_results WHERE id=$test_id/ );
    ok( ($test_id == 1 && $api_test_id eq $test_id || $test_id == 2 && $api_test_id eq $hash_id), "API start_domain_test -> id returned by the api is OK: [$api_test_id]" );

    # test test_progress API
    ok( $engine->test_progress( $api_test_id ) == 0 , 'API test_progress -> OK');

	use_ok( 'Zonemaster::Backend::Config' );
	my $config = Zonemaster::Backend::Config->load_config();
	
    use_ok( 'Zonemaster::Backend::TestAgent' );
	Zonemaster::Backend::TestAgent->new( { db => "Zonemaster::Backend::DB::$db_backend", config => $config } )->run( $api_test_id );

    sleep( 5 );
    ok( $engine->test_progress( $api_test_id ) > 0 , 'API test_progress -> Test started');

    foreach my $i ( 1 .. 12 ) {
        sleep( 5 );
        my $progress = $engine->test_progress( $api_test_id );
        diag "pregress: $progress";
        last if ( $progress == 100 );
    }
    ok( $engine->test_progress( $api_test_id ) == 100 , 'API test_progress -> Test finished' );
    my $test_results = $engine->get_test_results( { id => $api_test_id, language => 'fr-FR' } );
    ok( defined $test_results->{id} , 'API get_test_results -> [id] paramater present' );
    ok( defined $test_results->{params} , 'API get_test_results -> [params] paramater present' );
    ok( defined $test_results->{creation_time} , 'API get_test_results -> [creation_time] paramater present' );
    ok( defined $test_results->{results} , 'API get_test_results -> [results] paramater present' );
    ok( scalar( @{ $test_results->{results} } ) > 1 , 'API get_test_results -> [results] paramater contains data' );
}

# add test user
ok( $engine->add_api_user( { username => "zonemaster_test", api_key => "zonemaster_test's api key" } ) == 1, 'API add_api_user OK' );

my $user_check_query;
if ($db_backend eq 'PostgreSQL') {
	$user_check_query = q/SELECT * FROM users WHERE user_info->>'username' = 'zonemaster_test'/;
}
elsif ($db_backend eq 'MySQL') {
	$user_check_query = q/SELECT * FROM users WHERE username = 'zonemaster_test'/;
}

ok(
	scalar(
		$engine->{db}
			->dbh->selectrow_array( $user_check_query )
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
ok( $test_history->[0]->{id} eq '1' || $test_history->[1]->{id} eq '1' );
ok( length($test_history->[0]->{id}) == 16 || length($test_history->[1]->{id}) == 16 );

done_testing();

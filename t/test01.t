use strict;
use warnings;
use 5.10.1;

use Data::Dumper;
use Test::More;   # see done_testing()

use FindBin qw($RealScript $Script $RealBin $Bin);
FindBin::again();
##################################################################
my $PROJECT_NAME = "zonemaster-backend/t";

my $SCRITP_DIR = __FILE__;
$SCRITP_DIR = $Bin unless ($SCRITP_DIR =~ /^\//);

#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "RealScript:$RealScript\n";
#warn "Script:$Script\n";
#warn "RealBin:$RealBin\n";
#warn "Bin:$Bin\n";
#warn "__PACKAGE__:".__PACKAGE__;
#warn "__FILE__:".__FILE__;

my ($PROD_DIR) = ($SCRITP_DIR =~ /(.*?\/)$PROJECT_NAME/);
#warn "PROD_DIR:$PROD_DIR\n";

my $PROJECT_BASE_DIR = $PROD_DIR.$PROJECT_NAME."/";
#warn "PROJECT_BASE_DIR:$PROJECT_BASE_DIR\n";
unshift(@INC, $PROJECT_BASE_DIR);
##################################################################

my $runner_dir = $PROD_DIR."zonemaster-backend/JobRunner";
unshift(@INC, $runner_dir) unless $INC{$runner_dir};

# Require Engine.pm test
require_ok( 'Engine' );
#require Engine;

# Create Engine object
my $engine = Engine->new({ db => 'ZonemasterDB::SQLite'} );
isa_ok($engine, 'Engine');

# create a new memory SQLite database
ok($engine->{db}->create_db());

# add test user
ok($engine->add_api_user({username => "zonemaster_test", api_key => "zonemaster_test's api key"}) == 1);
ok(scalar($engine->{db}->dbh->selectrow_array(q/SELECT * FROM users WHERE user_info like '%zonemaster_test%'/)) == 1);

# add a new test to the db
my $frontend_params_1 = {
        client_id => 'Zonemaster CGI/Dancer/node.js', # free string
        client_version => '1.0',                        # free version like string
        
        domain => 'afnic.fr',                         # content of the domain text field
        advanced => 1,                          # 0 or 1, is the advanced options checkbox checked
        ipv4 => 1,                                                      # 0 or 1, is the ipv4 checkbox checked
        ipv6 => 1,                                                      # 0 or 1, is the ipv6 checkbox checked
        profile => 'test_profile_1',       # the id if the Test profile listbox
        nameservers => [                                        # list of the namaserves up to 32
                { ns => 'ns1.nic.fr', ip => '1.1.1.1'},                   # key values pairs representing nameserver => namesterver_ip
                { ns => 'ns2.nic.fr', ip => '192.134.4.1'},
        ],
        ds_digest_pairs => [                            # list of DS/Digest pairs up to 32
                { algorithm => 'sha1', digest => '0123456789012345678901234567890123456789'},                   # key values pairs representing ds => digest
                { algorithm => 'sha256', digest => '0123456789012345678901234567890123456789012345678901234567890123'},                   # key values pairs representing ds => digest
        ],
};
ok($engine->start_domain_test($frontend_params_1) == 1);
ok(scalar($engine->{db}->dbh->selectrow_array(q/SELECT id FROM test_results WHERE id=1/)) == 1);

# test test_progress API
ok($engine->test_progress(1) == 0);

require_ok('Runner');
my $command = qq/perl -I$runner_dir -MRunner -E'Runner->new\(\{ db => "ZonemasterDB::SQLite"\} \)->run\(1\)'/;
system ("$command &");

sleep(5);
ok($engine->test_progress(1) > 0);

foreach my $i (1..12) {
	sleep(5);
	my $progress = $engine->test_progress(1);
	print STDERR "pregress: $progress\n";
	last if ($progress == 100);
}
ok($engine->test_progress(1) == 100);
my $test_results = $engine->get_test_results({ id => 1, language => 'fr-FR' });
ok(defined $test_results->{id}, 'TEST1 $test_results->{id} defined');
ok(defined $test_results->{params}, 'TEST1 $test_results->{params} defined');
ok(defined $test_results->{creation_time}, 'TEST1 $test_results->{creation_time} defined');
ok(defined $test_results->{results}, 'TEST1 $test_results->{results} defined');
ok(scalar(@{$test_results->{results}}) > 1, 'TEST1 got some results');

done_testing();
use strict;
use warnings;
use utf8;
use 5.10.1;

use Data::Dumper;
use DBI qw(:utils);
use IO::CaptureOutput qw/capture_exec/;
use POSIX;
use Time::HiRes;
use Proc::ProcessTable;

local $| = 1;

use Zonemaster::Backend::Config;

use FindBin qw($RealScript $Script $RealBin $Bin);
FindBin::again();
##################################################################
my $PROJECT_NAME = "zonemaster-backend";

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
###################################################################

my $JOB_RUNNER_DIR = $PROD_DIR."zonemaster-backend/script/crontab_job_runner/";
my $LOG_DIR = Zonemaster::Backend::Config->load_config()->LogDir();
my $perl_command = Zonemaster::Backend::Config->load_config()->PerlInterpreter();
my $polling_interval = Zonemaster::Backend::Config->load_config()->PollingInterval();
my $zonemaster_timeout_interval = Zonemaster::Backend::Config->load_config()->MaxZonemasterExecutionTime();
my $frontend_slots = Zonemaster::Backend::Config->load_config()->NumberOfProcessesForFrontendTesting();
my $batch_slots = Zonemaster::Backend::Config->load_config()->NumberOfProcessesForBatchTesting();

my $connection_string = Zonemaster::Backend::Config->load_config()->DB_connection_string();
my $dbh = DBI->connect($connection_string, Zonemaster::Backend::Config->load_config()->DB_user(), Zonemaster::Backend::Config->load_config()->DB_password(), {RaiseError => 1, AutoCommit => 1});


sub clean_hung_processes {
	my $t = new Proc::ProcessTable;

	foreach my $p (@{$t->table}) {
		if (($p->cmndline =~ /execute_zonemaster_P10\.pl/ || $p->cmndline =~ /execute_zonemaster_P5\.pl/) && $p->cmndline !~ /sh -c/) {
			if (time() - $p->start > $zonemaster_timeout_interval) {
				say "Killing hung Zonemaster test process: [".$p->cmndline."]";
				$p->kill(9);
			}
		}
	}
}

sub can_start_new_worker {
	my ($priority, $test_id) = @_;
	my $result = 0;
	
	my @nb_instances = split(/\n+/, `ps -ef | grep "execute_zonemaster_P$priority.pl" | grep -v "sh -c" | grep -v grep | grep -v tail`);
	my @same_test_id = split(/\n+/, `ps -ef | grep "execute_zonemaster_P$priority.pl $test_id " | grep -v "sh -c" | grep -v grep | grep -v tail`);
	
	my $max_slots = 0;
	if ($priority == 5) {
		$max_slots = $batch_slots;
	}
	elsif ($priority == 10) {
		$max_slots = $frontend_slots;
	}
	
	$result = 1 if (scalar @nb_instances < $max_slots && !@same_test_id);
}

sub process_jobs {
	my ($priority, $start_time) = @_;

	my $query = "SELECT id FROM test_results WHERE progress=0 AND priority=$priority ORDER BY id LIMIT 10";
	my $sth1 = $dbh->prepare($query);
	$sth1->execute;
	while (my $h = $sth1->fetchrow_hashref) {
		if (can_start_new_worker($priority, $h->{id})) {
			my $command = "$perl_command $JOB_RUNNER_DIR/execute_zonemaster_P$priority.pl $h->{id} > $LOG_DIR/execute_zonemaster_P$priority"."_$h->{id}_$start_time.log 2>&1 &";
			say $command;
			system($command);
		}
	}
	$sth1->finish();
}

my $start_time = time();
do {
	clean_hung_processes();
	process_jobs(10, $start_time);
	process_jobs(5, $start_time);
	say '----------------------- '.strftime("%F %T", localtime()).' ------------------------';
	Time::HiRes::sleep($polling_interval);
} while (time() - $start_time < (15*60 - 15));

say "WORKED FOR 15 minutes LEAVING";

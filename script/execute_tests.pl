#!/usr/bin/env perl

use strict;
use warnings;
use 5.14.2;

use DBI qw(:utils);
use IO::CaptureOutput qw/capture_exec/;
use POSIX;
use Time::HiRes;
use Proc::ProcessTable;

local $| = 1;

require Zonemaster::WebBackend::Config;

my $LOG_DIR                     = Zonemaster::WebBackend::Config->LogDir();
my $perl_command                = Zonemaster::WebBackend::Config->PerlIntereter();
my $polling_interval            = Zonemaster::WebBackend::Config->PollingInterval();
my $zonemaster_timeout_interval = Zonemaster::WebBackend::Config->MaxZonemasterExecutionTime();
my $frontend_slots              = Zonemaster::WebBackend::Config->NumberOfProfessesForFrontendTesting();
my $batch_slots                 = Zonemaster::WebBackend::Config->NumberOfProfessesForBatchTesting();

my $connection_string = Zonemaster::WebBackend::Config->DB_connection_string();
my $dbh               = DBI->connect(
    $connection_string,
    Zonemaster::WebBackend::Config->DB_user(),
    Zonemaster::WebBackend::Config->DB_password(),
    { RaiseError => 1, AutoCommit => 1 }
);

sub clean_hung_processes {
    my $t = new Proc::ProcessTable;

    foreach my $p ( @{ $t->table } ) {
        if ( ( $p->cmndline =~ /execute_zonemaster_P10\.pl/ || $p->cmndline =~ /execute_zonemaster_P5\.pl/ )
            && $p->cmndline !~ /sh -c/ )
        {
            if ( time() - $p->start > $zonemaster_timeout_interval ) {
                say "Killing hung Zonemaster test process: [" . $p->cmndline . "]";
                $p->kill( 9 );
            }
        }
    }
}

sub can_start_new_worker {
    my ( $priority, $test_id ) = @_;
    my $result = 0;

    my @nb_instances = split( /\n+/,
        `ps -ef | grep "execute_zonemaster_P$priority.pl" | grep -v "sh -c" | grep -v grep | grep -v tail` );
    my @same_test_id = split( /\n+/,
        `ps -ef | grep "execute_zonemaster_P$priority.pl $test_id " | grep -v "sh -c" | grep -v grep | grep -v tail` );

    my $max_slots = 0;
    if ( $priority == 5 ) {
        $max_slots = $batch_slots;
    }
    elsif ( $priority == 10 ) {
        $max_slots = $frontend_slots;
    }

    $result = 1 if ( scalar @nb_instances < $max_slots && !@same_test_id );
}

sub process_jobs {
    my ( $priority, $start_time ) = @_;

    my $query = "SELECT id FROM test_results WHERE progress=0 AND priority=$priority ORDER BY id LIMIT 10";
    my $sth1  = $dbh->prepare( $query );
    $sth1->execute;
    while ( my $h = $sth1->fetchrow_hashref ) {
        if ( can_start_new_worker( $priority, $h->{id} ) ) {
            my $command =
"$perl_command execute_zonemaster_P$priority.pl $h->{id} > $LOG_DIR/execute_zonemaster_P$priority"
              . "_$h->{id}_$start_time.log 2>&1 &";
            say $command;
            system( $command);
        }
    }
    $sth1->finish();
}

my $start_time = time();
do {
    clean_hung_processes();
    process_jobs( 10, $start_time );
    process_jobs( 5,  $start_time );
    say '----------------------- ' . strftime( "%F %T", localtime() ) . ' ------------------------';
    Time::HiRes::sleep( $polling_interval );
} while ( time() - $start_time < ( 15 * 60 - 15 ) );

say "WORKED FOR 15 minutes LEAVING";

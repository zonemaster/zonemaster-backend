#!/usr/bin/env perl
use strict;
use warnings;

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB;
use Net::Prometheus;

my $client = Net::Prometheus->new;

my $tests_gauge = $client->new_gauge(
    name => 'zonemaster_tests_total',
    help => 'Total number of tests',
    labels => [ 'state' ],
);

my $config = Zonemaster::Backend::Config->load_config();
my $dbtype = $config->DB_engine;
my $dbclass = Zonemaster::Backend::DB->get_db_class( $dbtype );
my $db = $dbclass->from_config( $config );

my $prom_app = $client->psgi_app;

sub {
    my $queued = $db->dbh->selectrow_hashref('SELECT count(*) from test_results WHERE progress = 0');
    $tests_gauge->labels('queued')->set($queued->{count});

    my $finished = $db->dbh->selectrow_hashref('SELECT count(*) from test_results WHERE progress = 100');
    $tests_gauge->labels('finished')->set($finished->{count});

    my $running = $db->dbh->selectrow_hashref('SELECT count(*) from test_results WHERE progress > 0 and progress < 100');
    $tests_gauge->labels('running')->set($running->{count});

    $prom_app->(@_);
};

#!/usr/bin/env perl

use strict;
use warnings;

use Zonemaster::Backend::Config;
use Zonemaster::Backend::DB;

my $config = Zonemaster::Backend::Config->load_config();
my $db_engine = $config->DB_engine;

my $db_class = Zonemaster::Backend::DB->get_db_class( $db_engine );

my $db = $db_class->from_config( $config );
$db->create_schema();

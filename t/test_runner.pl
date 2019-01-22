use strict;
use warnings;
use utf8;

use lib '/home/toma/PROD/zonemaster/zonemaster-backend/JobZonemaster::Backend::TestAgent';
use Zonemaster::Backend::TestAgent;
use Zonemaster::Backend::Config;

my $config = Zonemaster::Backend::Config->load_config();

my $r = Zonemaster::Backend::TestAgent->new( { db => 'Zonemaster::Backend::DB::CouchDB', config => $config } );
$r->run( '648390b633d671440378100c9d00bb95' );

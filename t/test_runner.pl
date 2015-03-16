use strict;
use warnings;
use utf8;

use lib '/home/toma/PROD/zonemaster/zonemaster-backend/JobZonemaster::WebBackend::Runner';
use Zonemaster::WebBackend::Runner;

my $r = Zonemaster::WebBackend::Runner->new( { db => 'Zonemaster::WebBackend::DB::CouchDB' } );
$r->run( '648390b633d671440378100c9d00bb95' );

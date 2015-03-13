use strict;
use warnings;
use 5.10.1;

use Zonemaster::WebBackend::Runner;

Zonemaster::WebBackend::Runner->new()->run( $ARGV[0] );

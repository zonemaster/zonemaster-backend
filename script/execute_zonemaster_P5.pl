use strict;
use warnings;
use 5.14.2;

use Zonemaster::WebBackend::Runner;

Zonemaster::WebBackend::Runner->new()->run( $ARGV[0] );

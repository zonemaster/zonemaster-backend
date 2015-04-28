use strict;
use warnings;
use utf8;
use 5.10.1;

use strict;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

use Client;

my $c = Client->new( { url => 'http://localhost:5000' } );

say "Client->get_data_from_parent_zone:".Dumper($c->get_data_from_parent_zone("nic.fr"));

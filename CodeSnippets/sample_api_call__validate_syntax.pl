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

my $frontend_params = {
	ipv4 => 1,
	ipv6 => 1,
};

$frontend_params->{nameservers} = [    # list of the namaserves up to 32
	{ ns => 'ns1.nic.fr', ip => '1.2.3.4' },       # key values pairs representing nameserver => namesterver_ip
	{ ns => 'ns2.nic.fr', ip => '192.134.4.1' },
];

$frontend_params->{domain} = 'afnic.fr';

say "Client->validate_syntax:".Dumper($c->validate_syntax($frontend_params));

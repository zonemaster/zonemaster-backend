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
    client_id      => 'Zonemaster CGI/Dancer/node.js',    # free string
    client_version => '1.0',                              # free version like string

    domain      => 'afnic.fr',                            # content of the domain text field
    advanced    => 1,                                     # 0 or 1, is the advanced options checkbox checked
    ipv4        => 1,                                     # 0 or 1, is the ipv4 checkbox checked
    ipv6        => 1,                                     # 0 or 1, is the ipv6 checkbox checked
    profile     => 'test_profile_1',                      # the id if the Test profile listbox
    nameservers => [                                      # list of the namaserves up to 32
        { ns => 'ns1.nic.fr', ip => '1.1.1.1' },          # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ],
    ds_info => [                                  # list of DS/Digest pairs up to 32
        { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
    ],
};

say "Client->validate_syntax:" . Dumper( $c->validate_syntax( $frontend_params ) );

=coment
say "Client->version_info:".Dumper($c->version_info("test param"));

say "Client->get_ns_ips:".Dumper($c->get_ns_ips("ns1.nic.fr"));

say "Client->get_data_from_parent_zone:".Dumper($c->get_data_from_parent_zone("nic.fr"));

say "Client->validate_domain_syntax:".Dumper($c->validate_domain_syntax("nic.fr"));

my $frontend_params = {
    client_id      => 'Zonemaster CGI/Dancer/node.js',    # free string
    client_version => '1.0',                              # free version like string

    domain      => 'afnic-2.fr',                            # content of the domain text field
    advanced    => 1,                                     # 0 or 1, is the advanced options checkbox checked
    ipv4        => 1,                                     # 0 or 1, is the ipv4 checkbox checked
    ipv6        => 1,                                     # 0 or 1, is the ipv6 checkbox checked
    profile     => 'test_profile_1',                      # the id if the Test profile listbox
    nameservers => [                                      # list of the namaserves up to 32
        { ns => 'ns1.nic.fr', ip => '1.1.1.1' },          # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ],
    ds_info => [                                  # list of DS/Digest pairs up to 32
        { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
    ],
};

my $id_test = $c->start_domain_test($frontend_params);
say "start_domain_test: ".Dumper($id_test);
say "--------------------------";

say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(1);
say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(1);
say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(2);
say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(2);
say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(3);
say "test_progress: ".Dumper($c->test_progress($id_test));
sleep(3);
say "test_progress: ".Dumper($c->test_progress($id_test));
say "--------------------------";


say "get_test_results: ".Dumper($c->get_test_results( { id => $id_test, language => 'en' } ));
say "--------------------------";

my $frontend_params1 = {
    client_id      => 'Zonemaster CGI/Dancer/node.js',    # free string
    client_version => '1.0',                              # free version like string

    domain      => 'afnic-2.fr',                            # content of the domain text field
    advanced    => 1,                                     # 0 or 1, is the advanced options checkbox checked
    ipv4        => 1,                                     # 0 or 1, is the ipv4 checkbox checked
    ipv6        => 1,                                     # 0 or 1, is the ipv6 checkbox checked
    profile     => 'test_profile_1',                      # the id if the Test profile listbox
    nameservers => [                                      # list of the namaserves up to 32
        { ns => 'ns1.nic.fr', ip => '1.1.1.1' },          # key values pairs representing nameserver => namesterver_ip
        { ns => 'ns2.nic.fr', ip => '192.134.4.1' },
    ],
    ds_info => [                                  # list of DS/Digest pairs up to 32
        { keytag => 11627, algorithm => 8, digtype => 2, digest => 'a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448' },
    ],
};

my $offset = 0;
my $limit = 10;
say "get_test_history: ".Dumper($c->get_test_history( { frontend_params => $frontend_params1, offset => $offset, limit => $limit } ));
say "--------------------------";
=cut

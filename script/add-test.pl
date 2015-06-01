#!/usr/bin/env perl

use 5.14.2;
use warnings;

use Zonemaster::WebBackend::Engine;

if ( @ARGV == 0 ) {
    say "usage: $0 dname [dname...]";
    exit;
}

my $e = Zonemaster::WebBackend::Engine->new;

foreach my $domain ( @ARGV ) {
    $e->start_domain_test(
        {
            client_id      => 'Add Script',
            client_version => '1.0',
            domain         => $domain,
            advanced       => 0,                   # 0 or 1, is the advanced options checkbox checked
            ipv4           => 1,                   # 0 or 1, is the ipv4 checkbox checked
            ipv6           => 1,                   # 0 or 1, is the ipv6 checkbox checked
            profile        => 'test_profile_1',    # the id if the Test profile listbox (unused)

            nameservers     => [],
            ds_digest_pairs => [],
        }
    );
}

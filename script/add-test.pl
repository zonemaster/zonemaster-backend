#!/usr/bin/env perl

use 5.14.2;
use warnings;

use Encode qw[decode_utf8];
use Zonemaster::Backend::RPCAPI;

binmode STDOUT, ':utf8';

if ( @ARGV == 0 ) {
    say "usage: $0 dname [dname...]";
    exit;
}

my $e = Zonemaster::Backend::RPCAPI->new;

foreach my $domain ( @ARGV ) {
    $domain = decode_utf8($domain);
    say "Starting for $domain";
    $e->start_domain_test(
        {
            client_id      => 'Add Script',
            client_version => '1.0',
            domain         => $domain,
            advanced       => 0,                   # 0 or 1, is the advanced options checkbox checked
            ipv4           => 1,                   # 0 or 1, is the ipv4 checkbox checked
            ipv6           => 1,                   # 0 or 1, is the ipv6 checkbox checked
            profile        => 'test_profile_1',    # the id if the Test profile listbox (unused)

        }
    );
}

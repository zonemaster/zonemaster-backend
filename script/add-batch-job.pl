#!/usr/bin/env perl

# This script is for testing purpose only.

use 5.14.2;
use warnings;

use Data::Dumper;
use Encode qw[decode_utf8];
use Zonemaster::Backend::RPCAPI;
use Digest::MD5 qw(md5_hex);

binmode STDOUT, ':utf8';

my $e = Zonemaster::Backend::RPCAPI->new;

say "Starting add_batch_job";
my @domains;
for (my $i = 0; $i < 100; $i++) {
    push(@domains, substr(md5_hex(rand(10000)), 0, 5).".fr");
}

#die Dumper(\@domains);

$e->add_api_user({ username => 'test_user', api_key => 'API_KEY_01'});

$e->add_batch_job(
    {
        client_id      => 'Add Script',
        client_version => '1.0',
        username       => 'test_user',
        api_key        => 'API_KEY_01',
        test_params    => {
            client_id      => 'Add Script',
            client_version => '1.0',
            ipv4           => 1,                   # 0 or 1, is the ipv4 checkbox checked
            ipv6           => 1,                   # 0 or 1, is the ipv6 checkbox checked
            profile        => 'default',           # the id if the Test profile listbox (unused)
        },
        domains => \@domains,
    }
    );

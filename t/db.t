use strict;
use warnings;

use Test::More;    # see done_testing()

use_ok( 'Zonemaster::Backend::DB' );
use_ok( 'JSON::PP' );

sub encode_and_fingerprint {
    my $params = shift;

    my $self = "Zonemaster::Backend::DB";
    my $encoded_params = $self->encode_params( $params );
    my $fingerprint = $self->generate_fingerprint( $params );

    return ( $encoded_params, $fingerprint );
}

subtest 'encoding and fingerprint' => sub {

    subtest 'missing properties' => sub {
        my $expected_encoded_params = '{"domain":"example.com","ds_info":[],"ipv4":true,"ipv6":true,"nameservers":[],"profile":"default"}';

        my %params = ( domain => "example.com" );

        my ( $encoded_params, $fingerprint ) = encode_and_fingerprint( \%params );
        is $encoded_params, $expected_encoded_params, 'domain only: the encoded strings should match';
        #diag ($fingerprint);

        $params{ipv4} = JSON::PP->true;
        my ( $encoded_params_ipv4, $fingerprint_ipv4 ) = encode_and_fingerprint( \%params );
        is $encoded_params_ipv4, $expected_encoded_params, 'add ipv4: the encoded strings should match';
        is $fingerprint_ipv4, $fingerprint, 'fingerprints should match';
    };

    subtest 'array properties' => sub {
        subtest 'ds_info' => sub {
            my %params1 = (
                domain => "example.com",
                ds_info => [{
                    algorithm => 8,
                    keytag => 11627,
                    digtype => 2,
                    digest => "a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448"
                }]
            );
            my %params2 = (
                ds_info => [{
                    digtype => 2,
                    algorithm => 8,
                    keytag => 11627,
                    digest => "a6cca9e6027ecc80ba0f6d747923127f1d69005fe4f0ec0461bd633482595448"
                }],
                domain => "example.com"
            );
            my ( $encoded_params1, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
            my ( $encoded_params2, $fingerprint2 ) = encode_and_fingerprint( \%params2 );
            is $fingerprint1, $fingerprint2, 'ds_info same fingerprint';
            is $encoded_params1, $encoded_params2, 'ds_info same encoded string';
        };

        subtest 'nameservers order' => sub {
            my %params1 = (
                domain => "example.com",
                nameservers => [
                    { ns => "ns2.nic.fr", ip => "192.134.4.1" },
                    { ns => "ns1.nic.fr" },
                    { ip => "192.0.2.1", ns => "ns3.nic.fr"}
                ]
            );
            my %params2 = (
                nameservers => [
                    { ns => "ns3.nic.fr", ip => "192.0.2.1" },
                    { ns => "ns1.nic.fr" },
                    { ip => "192.134.4.1", ns => "ns2.nic.fr"}
                ],
                domain => "example.com"
            );
            my %params3 = (
                domain => "example.com",
                nameservers => [
                    { ip => "", ns => "ns1.nic.fr" },
                    { ns => "ns3.nic.FR", ip => "192.0.2.1" },
                    { ns => "ns2.nic.fr", ip => "192.134.4.1" }
                ]
            );
            my %params4 = (
                domain => "example.com",
                nameservers => [
                    { ip => "192.134.4.1", ns => "nS2.Nic.FR"},
                    { ns => "Ns1.nIC.fR", ip => "" },
                    { ns => "ns3.nic.fr", ip => "192.0.2.1" }
                ]
            );

            my ( $encoded_params1, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
            my ( $encoded_params2, $fingerprint2 ) = encode_and_fingerprint( \%params2 );
            my ( $encoded_params3, $fingerprint3 ) = encode_and_fingerprint( \%params3 );
            my ( $encoded_params4, $fingerprint4 ) = encode_and_fingerprint( \%params4 );

            is $fingerprint1, $fingerprint2, 'nameservers: same fingerprint';
            is $encoded_params1, $encoded_params2, 'nameservers: same encoded string';

            is $fingerprint1, $fingerprint3, 'nameservers: same fingerprint (empty ip)';
            is $encoded_params1, $encoded_params3, 'nameservers: same encoded string (empty ip)';

            is $fingerprint1, $fingerprint4, 'nameservers: same fingerprint (ignore nameservers\' ns case)';
            is $encoded_params1, $encoded_params4, 'nameservers: same encoded string (ignore nameservers\' ns case)';
        };
    };

    subtest 'should be case insensitive' => sub {
        my %params1 = ( domain => "example.com" );
        my %params2 = ( domain => "eXamPLe.COm" );

        my ( $encoded_params1, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
        my ( $encoded_params2, $fingerprint2 ) = encode_and_fingerprint( \%params2 );
        is $fingerprint1, $fingerprint2, 'same fingerprint';
        is $encoded_params1, $encoded_params2, 'same encoded string';
    };

    subtest 'garbage properties set' => sub {
        my $expected_encoded_params = '{"client":"GUI v3.3.0","domain":"example.com","ds_info":[],"ipv4":true,"ipv6":true,"nameservers":[],"profile":"default"}';
        my %params1 = (
            domain => "example.com",
        );
        my %params2 = (
            domain => "example.com",
            client => "GUI v3.3.0"
        );
        my ( $encoded_params1, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
        my ( $encoded_params2, $fingerprint2 ) = encode_and_fingerprint( \%params2 );

        is $fingerprint1, $fingerprint2, 'leave out garbage property in fingerprint computation...';
        is $encoded_params2, $expected_encoded_params, '...but keep it in the encoded string';
    };

    subtest 'should have different fingerprints' => sub {
        subtest 'different profiles' => sub {
            my %params1 = (
                domain => "example.com",
                profile => "profile_1"
            );
            my %params2 = (
                domain => "example.com",
                profile => "profile_2"
            );
            my ( undef, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
            my ( undef, $fingerprint2 ) = encode_and_fingerprint( \%params2 );

            isnt $fingerprint1, $fingerprint2, 'different profiles, different fingerprints';
        };
        subtest 'different IP protocols' => sub {
            my %params1 = (
                domain => "example.com",
                ipv4 => "true",
                ipv6 => "false"
            );
            my %params2 = (
                domain => "example.com",
                ipv4 => "false",
                ipv6 => "true"
            );
            my ( undef, $fingerprint1 ) = encode_and_fingerprint( \%params1 );
            my ( undef, $fingerprint2 ) = encode_and_fingerprint( \%params2 );

            isnt $fingerprint1, $fingerprint2, 'different IP protocols, different fingerprints';
        };
    }
};

done_testing();

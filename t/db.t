use strict;
use warnings;

use Test::More;    # see done_testing()

use_ok( 'Zonemaster::Backend::DB' );
use_ok( 'JSON::PP' );

sub generate_fingerprint {
    return Zonemaster::Backend::DB::generate_fingerprint( undef, shift );
}

subtest 'encoding and fingerprint' => sub {

    subtest 'missing properties' => sub {
        my $expected_encoded_params = '{"domain":"example.com","ds_info":[],"ipv4":true,"ipv6":true,"nameservers":[],"priority":10,"profile":"default","queue":0}';

        my %params = ( domain => "example.com" );

        my ( $fingerprint, $encoded_params ) = generate_fingerprint( \%params );
        is $encoded_params, $expected_encoded_params, 'domain only: the encoded strings should match';
        #diag ($fingerprint);

        $params{ipv4} = JSON::PP->true;
        my ( $fingerprint_ipv4, $encoded_params_ipv4 ) = generate_fingerprint( \%params );
        is $encoded_params_ipv4, $expected_encoded_params, 'add ipv4: the encoded strings should match';
        is $fingerprint_ipv4, $fingerprint, 'fingerprints should match';
    };

    subtest 'should be case insensitive' => sub {
        my %params1 = ( domain => "example.com" );
        my %params2 = ( domain => "eXamPLe.COm" );

        my ( $fingerprint1, $encoded_params1 ) = generate_fingerprint( \%params1 );
        my ( $fingerprint2, $encoded_params2 ) = generate_fingerprint( \%params2 );
        is $fingerprint1, $fingerprint2, 'same fingerprint';
        is $encoded_params1, $encoded_params2, 'same encoded string';
    };

    subtest 'garbage properties set' => sub {
        my $expected_encoded_params = '{"domain":"example.com","ds_info":[],"ipv4":true,"ipv6":true,"nameservers":[],"priority":10,"profile":"default","queue":0}';
        my %params = (
            domain => "example.com",
            client => "GUI v3.3.0"
        );
        my ( $fingerprint, $encoded_params ) = generate_fingerprint( \%params );
        is $encoded_params, $expected_encoded_params, 'leave out garbage property';
    };
};

done_testing();

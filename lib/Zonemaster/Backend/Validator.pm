package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use JSON::Validator::Joi;
use Readonly;

Readonly my $IPV4_RE => qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$/;
Readonly my $IPV6_RE => qr/^([0-9a-f]{1,4}:[0-9a-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)\$|([0-9a-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\$/i;

Readonly my $API_KEY_RE             => qr/^[a-z0-9-_]{1,512}$/i;
Readonly my $CLIENT_ID_RE           => qr/^[a-z0-9-+~_.: ]{1,50}$/i;
Readonly my $CLIENT_VERSION_RE      => qr/^[a-z0-9-+~_.: ]{1,50}$/i;
Readonly my $DIGEST_RE              => qr/^[a-f0-9]{40}\$|^[a-f0-9]{64}\$/i;
Readonly my $IPADDR_RE              => qr/^$|$IPV4_RE|$IPV6_RE/;
Readonly my $JSONRPC_METHOD_RE      => qr/^[a-z0-9_-]*$/i;
Readonly my $LANGUAGE_RE            => qr/^[a-z]{2}(_[A-Z]{2})?$/;
Readonly my $PROFILE_NAME_RE        => qr/^[a-z0-9]$|^[a-z0-9][a-z0-9_-]{0,30}[a-z0-9]$/i;
Readonly my $RELAXED_DOMAIN_NAME_RE => qr/^[.]$|^.{2,254}$/;
Readonly my $TEST_ID_RE             => qr/^[0-9a-f]{16}$/;
Readonly my $USERNAME_RE            => qr/^[a-z0-9-.@]{1,50}$/i;

sub joi {
    return JSON::Validator::Joi->new;
}

sub new {
    my ( $type ) = @_;

    my $self = {};
    bless( $self, $type );

    return ( $self );
}

sub api_key {
    return joi->string->regex( $API_KEY_RE );
}
sub batch_id {
    return joi->integer->positive;
}
sub client_id {
    return joi->string->regex( $CLIENT_ID_RE );
}
sub client_version {
    return joi->string->regex( $CLIENT_VERSION_RE );
}
sub domain_name {
    return joi->string->regex( $RELAXED_DOMAIN_NAME_RE );
}
sub ds_info {
    return joi->object->strict->props(
        digest => joi->string->regex($DIGEST_RE)->required,
        algorithm => joi->integer->min(0)->required,
        digtype => joi->integer->min(0)->required,
        keytag => joi->integer->min(0)->required,
    );
}
sub ip_address {
    return joi->string->regex( $IPADDR_RE );
}
sub nameserver {
    return joi->object->strict->props(
            ns => joi->string->required,
            ip => ip_address()
    );
}
sub priority {
    return joi->integer;
}
sub profile_name {
    return joi->string->regex( $PROFILE_NAME_RE );
}
sub queue {
    return joi->integer;
}
sub test_id {
    return joi->string->regex( $TEST_ID_RE );
}
sub language_tag {
    return joi->string->regex( $LANGUAGE_RE );
}
sub username {
    return joi->string->regex( $USERNAME_RE );
}
sub jsonrpc_method {
    return joi->string->regex( $JSONRPC_METHOD_RE );
}

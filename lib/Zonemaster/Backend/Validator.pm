package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use JSON::Validator "joi";

sub new {
    my ( $type ) = @_;

    my $self = {};
    bless( $self, $type );

    return ( $self );
}

my $ipv4_regex = "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$";
my $ipv6_regex = "^([0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)\$|([0-9A-Fa-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\$";

sub api_key {
    return joi->string;
}
sub batch_id {
    return joi->integer->positive;
}
sub client_id {
    return joi->string;
}
sub client_version {
    return joi->string;
}
sub domain_name {
    return joi->string->max(254);
}
sub ds_info {
    return joi->object->strict->props(
        digest => joi->string->regex("^[A-Fa-f0-9]{40}\$|^[A-Fa-f0-9]{64}\$")->required,
        algorithm => joi->integer->min(0),
        digtype => joi->integer->min(0),
        keytag => joi->integer->min(0)
);
}
sub ip_address {
    return joi->string->regex($ipv4_regex."|".$ipv6_regex);
}
sub location {
    return joi->object->strict->props(
    isp => joi->string,
    country => joi->string,
    city => joi->string,
    longitude => joi->string->regex("^(\+|-)?(?:180(?:(?:\.0{1,6})?)|(?:[0-9]|[1-9][0-9]|1[0-7][0-9])(?:(?:\.[0-9]{1,6})?))\$"),
    latitude => joi->string->regex("^(\+|-)?(?:90(?:(?:\.0{1,6})?)|(?:[0-9]|[1-8][0-9])(?:(?:\.[0-9]{1,6})?))\$"),
);
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
    return joi->string->regex('^[a-zA-Z0-9]$|^[a-zA-Z0-9][a-zA-Z0-9_-]{0,30}[a-zA-Z0-9]$');
}
sub queue {
    return joi->integer;
}
sub test_id {
    return joi->string;
}
sub translation_language {
    return joi->string->length(2);
}
sub username {
    return joi->string;
}
sub jsonrpc_method {
    return joi->string->regex("[a-zA-Z0-9_-]*");
}
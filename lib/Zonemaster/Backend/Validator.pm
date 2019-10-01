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
    return joi->string->regex('^[a-zA-Z0-9-_]{1,512}$');
}
sub batch_id {
    return joi->integer->positive;
}
sub client_id {
    return joi->string->regex('^[a-zA-Z0-9-+~_.: ]{1,50}$');
}
sub client_version {
    return joi->string->regex('^[a-zA-Z0-9-+~_.: ]{1,50}$');
}
sub domain_name {
    return joi->string->regex('^[.]$|^.{2,254}$');
}
sub ds_info {
    return joi->object->strict->props(
        digest => joi->string->regex("^[A-Fa-f0-9]{40}\$|^[A-Fa-f0-9]{64}\$")->required,
        algorithm => joi->integer->min(0)->required,
        digtype => joi->integer->min(0)->required,
        keytag => joi->integer->min(0)->required,
    );
}
sub ip_address {
    return joi->string->regex($ipv4_regex."|".$ipv6_regex);
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
    return joi->string->regex('^[0-9]$|^[1-9][0-9]{1,8}$|^[0-9a-f]{16}$');
}
sub translation_language {
    return joi->string->regex('^[a-zA-Z0-9-_.@]{1,30}$');
}
sub username {
    return joi->string->regex('^[a-zA-Z0-9-.@]{1,50}$');
}
sub jsonrpc_method {
    return joi->string->regex('^[a-zA-Z0-9_-]*$');
}

package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use JSON::Validator "joi";


my $ipv4_regex = "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$";
my $ipv6_regex = "^([0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)\$|([0-9A-Fa-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\$";

our $api_key = joi->string;
our $batch_id = joi->integer->positive;
our $client_id = joi->string;
our $client_version = joi->string;
our $domain_name = joi->string->max(254);
our $ds_info = joi->object->strict->props(
        digest => joi->string->regex("^[A-Fa-f0-9]{40,64}\$")->required,
        algorithm => joi->integer->min(0),
        digtype => joi->integer->min(0),
        keytag => joi->integer->min(0)
);
our $ip_address = joi->string->regex($ipv4_regex."|".$ipv6_regex);
our $location = joi->object->strict->props(
    isp => joi->string,
    country => joi->string,
    city => joi->string,
    longitude => joi->string->regex("^(\+|-)?(?:180(?:(?:\.0{1,6})?)|(?:[0-9]|[1-9][0-9]|1[0-7][0-9])(?:(?:\.[0-9]{1,6})?))\$"),
    latitude => joi->string->regex("^(\+|-)?(?:90(?:(?:\.0{1,6})?)|(?:[0-9]|[1-8][0-9])(?:(?:\.[0-9]{1,6})?))\$"),
);
our $nameserver = joi->object->strict->props(
            ns => joi->string->required,
            ip => $ip_address
    );
our $priority = joi->integer;
our $profil_name = joi->string->regex("^(?![-_])[a-zA-Z0-9-_]{1,32}(?<![-_])\$")->min(1)->max(32);
our $pourcentage = joi->integer->min(0)->max(100);
our $queue = joi->integer;
our $severity_level = joi->string->regex("DEBUG|INFO|NOTICE|WARNING|ERROR|CRITICAL");
our $test_id = joi->string;
our $timestamp = joi->date_time;
our $translate_language = joi->string->length(2);
our $unsigned_integer = joi->integer->min(0);
our $username = joi->string;
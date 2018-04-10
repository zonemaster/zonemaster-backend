package Zonemaster::Backend::Validator;

our $VERSION = '0.1.0';

use strict;
use warnings;
use 5.14.2;

use JSON::Validator "joi";

my $ipv4_regex = "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$";
my $ipv6_regex = "^([0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)\$|([0-9A-Fa-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\$";


my %json_schema = (
    get_ns_ips => joi->object->props( ns_name => joi->string->required )->strict,
    get_data_from_parent_zone => joi->object->props(
        domain   => joi->string->required
    )->strict,
    validate_syntax => joi->object->strict(
        ipv4 => joi->boolean,
        ipv6 => joi->boolean,
        ds_info => joi->array->items(
            joi->object->props(
                digest => joi->string->required,
                algorithm => joi->integer->min(0),
                digtype => joi->integer->min(0),
                keytag => joi->integer->min(0)
            )
        ),
        nameservers => joi->array->items(
            joi->object->props(
                ns => joi->string,
                ip => joi->string->regex($ipv4_regex."|".$ipv6_regex)
            )
        ),
        profile => joi->string,
        client_id => joi->string,
        client_version => joi->string,
        user_ip => joi->string->regex($ipv4_regex."|".$ipv6_regex),
        user_location_info => joi->string,
        config => joi->string,
        domain => joi->string->required,
        user_ip => joi->string->regex($ipv4_regex."|".$ipv6_regex),
        user_location_info => joi->string,
        priority => joi->string,
        queue => joi->string
    ),
    start_domain_test => joi->object->props(
            domain => joi->string->required,
            ipv4 => joi->boolean,
            ipv6 => joi->boolean,
            ds_info => joi->array->items(
                                   joi->object->props(
                                       digest => joi->string->required,
                                       algorithm => joi->integer->min(0),
                                       digtype => joi->integer->min(0),
                                       keytag => joi->integer->min(0)
                                   )
                               ),
            nameservers => joi->array->items(
                joi->object->props(
                    ns => joi->string,
                    ip => joi->string->regex($ipv4_regex."|".$ipv6_regex)
                )
            ),
            profile => joi->string,
            client_id => joi->string,
            client_version => joi->string,
            user_ip => joi->string->regex($ipv4_regex."|".$ipv6_regex),
            user_location_info => joi->string,
            config => joi->string,
            priority => joi->string,
            queue => joi->string
        ),
        test_progress => joi->object->props(
            test_id => joi->string->token->required
        ),
        get_test_params => joi->object->props(
                                   test_id => joi->string->token->required
                               ),
        get_test_results => joi->object->props(
            id => joi->string->token->required,
            language => joi->string->length(2)
        ),
        get_test_history => joi->object->props(
            offset => joi->integer->min(0),
            limit => joi->integer->min(0),
            frontend_params => joi->object->props(
                domain => joi->string->required,
                ipv4 => joi->boolean,
                ipv6 => joi->boolean,
                ds_info => joi->array->items(
                                       joi->object->props(
                                           digest => joi->string->required,
                                           algorithm => joi->integer->min(0),
                                           digtype => joi->integer->min(0),
                                           keytag => joi->integer->min(0)
                                       )
                                   ),
                nameservers => joi->array->items(
                    joi->object->props(
                        ns => joi->string,
                        ip => joi->string->regex($ipv4_regex."|".$ipv6_regex)
                    )
                ),
                profile => joi->string,
                client_id => joi->string,
                client_version => joi->string,
                config => joi->string,
            )
        ),
        add_api_user => joi->object->props(
            username => joi->string->required,
            api_key => joi->string->required,
        ),
        add_batch_job => joi->object->props(
            username => joi->string->required,
            api_key => joi->string->required,
            domains => joi->array->items(joi->string),
            test_params => joi->object->props(
                ipv4 => joi->boolean,
                ipv6 => joi->boolean,
                ds_info => joi->array->items(
                    joi->object->props(
                        digest => joi->string->required,
                        algorithm => joi->integer->min(0),
                        digtype => joi->integer->min(0),
                        keytag => joi->integer->min(0)
                    )
                ),
                nameservers => joi->array->items(
                    joi->object->props(
                        ns => joi->string,
                        ip => joi->string->regex($ipv4_regex."|".$ipv6_regex)
                    )
                ),
                profile => joi->string,
                client_id => joi->string,
                client_version => joi->string,
                user_ip => joi->string->regex($ipv4_regex."|".$ipv6_regex),
                user_location_info => joi->string,
                config => joi->string
            )
        ),
        get_batch_job_result =>  joi->object->props(
            batch_id => joi->string->token->required
        )
);

#Strict mode of JSON::Validator doesn't work ?
my %json_schema_properties = (
    get_ns_ips => ['ns_name'],
    get_data_from_parent_zone => ['domain'],
    validate_syntax => ['domain','ipv4','ipv6', 'ds_info', 'nameservers', 'profile', 'client_id', 'client_version',
    'user_ip', 'user_location_info', 'config', 'priority', 'queue'],
    start_domain_test => ['domain','ipv4','ipv6', 'ds_info', 'nameservers', 'profile', 'client_id', 'client_version',
    'user_ip', 'user_location_info', 'config', 'priority', 'queue'],
    test_progress => ['test_id'],
    get_test_params => ['test_id'],
    get_test_results => ['id', 'language'],
    get_test_history => ['offset', 'limit', 'frontend_params', 'domain','ipv4','ipv6', 'ds_info', 'nameservers',
    'profile', 'client_id', 'client_version', 'config'],
    add_api_user => ['username', 'api_key'],
    add_batch_job => ['test_params', 'username', 'api_key', 'domains','ipv4','ipv6', 'ds_info', 'nameservers', 'profile',
    'client_id', 'client_version', 'user_ip', 'user_location_info', 'config', 'priority', 'queue'],
    get_batch_job_result => ['batch_id']
);


sub Validate {
    my ( $self, $action, $params ) = @_;

    foreach my $k ( keys %$params ) {
        die "Unknown option [$k] in parameters \n"
          unless ( $k !~ $json_schema_properties{$action} );
    }

    my @error = $json_schema{$action}->validate($params);

    die "@error \n" if  @error;
}

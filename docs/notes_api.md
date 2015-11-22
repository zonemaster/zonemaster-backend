# Common

All requests consist of JSON objects with four keys.

1) "jsonrpc"

    The value of this key is the fixed string `"2.0"`.

2) "method"

    The name of the method to be called.

3) "id"

    An id-value meant to connect a request with a response. The value
    has no meaning, and will simply be copied to the response.

4) "params"

    This key holds the parameters to the method being called.

All responses consist of JSON objects with three keys.

1) "jsonrpc"

    The value of this key is the fixed string `"2.0"`.

2) "id"

    An id-value meant to connect a request with a response. The value
    has no meaning, and is simply copied from the request.

3) "result"

    This key holds the results returned from the method that was called.

In the descriptions below, only the contents of the "params" (input)
and "result" (output) keys are discussed, since they are the only ones
where the content differs between different methods.

# API Methods

## version_info

### Input

None.

### Output

Version information string.

## get_ns_ips

### Input

A domain name.

### Output

A list of objects. The objects each have a single key and value. The
key is the domain name given as input. The value is an IP address for
the name, or the value `0.0.0.0` if the lookup returned no A or AAAA
records.

## get_data_from_parent_zone

### Input

A domain name.

### Output

An object with two keys, `ns_list` and `ds_list`.

The value of the `ns_list` key is a list of objects. Each object in
the list has two keys, `ns` and `ip`. The values of the `ns` key is
the domain name of a nameserver for the input name, and the value of
the `ip` is an IP address for that nameserver name or the value
`0.0.0.0`.

As of this writing, the value of the `ds_list` key is always an empty
list.

## validate_syntax

### Input

The input for this method is a JSON object. The object may have the
keys `domain`, `ipv4`, `ipv6`, `ds_info`, `nameservers`,
`profile`, `advanced`, `client_id` and `client_version`. If any other
key is present, an error will be returned.

If the key `nameservers` exists, its value must be a list of objects
each of which has exactly the two keys `ip` and `ns`. The value of the
`ns` key must meet the criteria described below for the `domain`
value, and the value of the `ip` key must be a syntactically valid
IPv4 or IPv6 address.

If the key `ds_info` exists, its value must be a list of
objects each of which has exactly the two keys `algorithm` and
`digest`. The value of the `algorithm` key must be either the string
`"sha1"`, in which case the value of the `digest` key must be 40
hexadecimal characters, or the value `"sha256"`, in which case the
value of the `digest` key must be 64 hexadecimal characters.

At least one of the keys `ipv4` and `ipv6` must exist and have one of
the values `1`, `0`, `true` or `false`.

If the key `advanced` exists, it must have one of the values `true`
and `false`.

If the key `profile` exists, it must have a value that is one of the
three strings `"default_profile"`, `"test_profile_1"` and
`"test_profile_2"`.

The key `domain` must exist and have a value that meets the following
criteria.

1) If the value contains characters outside the ASCII character set,
   the entire value must be possible to convert to IDNA format.

2) If the value is a single character, that character must be `.`.

3) The length of the value must not be greater than 254 characters.

4) When the value is split at `.` characters (after IDNA conversion,
   if needed), each component part must be at most 63 characters long.

5) Each such component part must also consist only of the characters
   `0` to `9`, `a` to `z`, `A` to `Z` and `-`.

If the `nameservers` key is _not_ set, a recursive query made by the
server to its locally configured resolver for `NS` records for the
value of the `domain` key must return a reply with at least one
resource record in the `answer` section.

### Output

An object with the two keys `message` and `status`. If all criteria
above were met, the `status` key will have as its value the string
`"ok"`. If not, it will have the value `"nok"`. The value of the
`message` key is a human-readable string with more details in the
status.

## start_domain_test

### Input

The same as for `validate_syntax`.

### Output

The numeric ID of a newly started test, or a test with the same
parameters started within the recent configurable short time.

## test_progress

### Input

A numeric test ID.

### Output

An integer value (possible encoded in a string) between 0 and 100
inclusive, describing the progress of the test in question as a
percentage.

## get_test_params

### Input

A numeric test ID.

### Output

A JSON object with the parameters used to start the test (that is, the
input parameters to `start_domain_test`).

## get_test_results

### Input

A JSON object with the two keys `id` and `language`. `id` is a numeric
test ID. `language` is a string where the two first characters are a
language code to be used by the translator. As of this writing, the
language codes that are expected to work are `"en"`, `"sv"` and
`"fr"`. If the code given does not work, the translator will use
English.

### Output

A JSON object with a the following keys and values:

* `batch_id`

    The ID number of the batch of tests this one belongs to. `null` if
    it does not belong to a batch.

* `creation_time`

    The time at which the test request was created.

* `domain`

    The name of the tested domain.

* `id`

    The numeric ID of the test.

* `params_deterministic_hash`

    An MD5 hash of the canonical JSON representation of the test
    parameters, used internally to identify repeated test request.

* `params`

    The parameters used to start the test (that is, the values used as
    input to `start_domain_test`).

* `priority`

    The priority of the test. Used by the backend execution daemon to
    determine the order in which tests are run, if there are more
    requests than available test slots.

* `progress`

    An integer in the interval 0 to 100 inclusive, showing the
    percentage of the test process that has been completed.

* `results`

    A list of objects representing the results of the test. Each
    object has three keys, `module`, `message` and `level`. The values
    of them are strings. The `module` is the test module that produced
    the result, the `level` is the severity of the message as set in
    the policy used (that is, one of the strings `DEBUG`, `INFO`,
    `NOTICE`, `WARNING`, `ERROR` and `CRITICAL`) and `message` is a
    human-readable text describing that particular result.

* `test_end_time`

    The time at which the test was completed.

* `test_start_time`

    The time at which the test was started.

## get_test_history

### Input

A JSON object with three keys, `frontend_params`, `offset` and
`limit`. The value of `frontend_params` is an object in turn, with the
keys `domain` and `nameservers`.

The values of `limit` and `offset` will be used as-is as the
corresponding values in SQL expressions. `domain` and `nameservers`
will be used to look up all tests for the given domain, separated
according to if they were started with a `nameservers` parameter or
not.

### Output

A JSON object with four keys. `id` is the numeric ID of the test.
`creation_time` is the time when the test request was created.
`advanced_options` is true if the corresponding flag was set in the
request. `overall_results` is the most severe problem level logged in
the test results.

## add_api_user

### Input

A JSON object with two keys, `username` and `api_key`. Both should be
strings, both are simply inserted into the users table in the
database.

### Output

The numeric ID of the just created user.

## add_batch_job

### Input

A JSON object with three keys, `username`, `api_key` and
`batch_params`. The first two are strings, and must match a pair
previously created with `add_api_user`.

`batch_params` is a JSON object. It should be exactly the same as the
input object described for `validate_syntax`, except that instead of
the `domain` key there should be a key `domains`. The value of this
key should be a list of strings with the names of domains to be
tested. All the domains will be tested using identical parameters. The
domain names should probably obey the rules for domain names, but in
this case no attempt is made to enforce those prior to starting the
tests.

### Output

## api1

### Input

None.

### Output

A string with the version of the Perl interpreter running the backend
(more specifically, the value of the `$]` variable in the Perl
interpreter).

# Examples

## Minimal request to start a test

```
{
    "domain": "example.org",
    "ipv4": true
}
```

## Non-minimal request to start a test

```

{
    "domain": "example.org",
    "ipv4": 1,
    "ipv6": 1,
    "ds_info": [],
    "profile": "default_profile",
    "advanced": false,
    "client_id": "Documentation Example",
    "client_version": "1.0",
    "nameservers": [
        {
            "ns": "ns1.example.org",
            "ip": "192.168.0.1"
        },
        {
            "ns": "ns2.example.org",
            "ip": "2607:f0d0:1002:51::4"
        }
    ]
}
```

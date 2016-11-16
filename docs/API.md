# API

## Purpose

This document describes the JSON-RPC API provided by the Zonemaster *Web backend*.
This API provides means to check the health of domains and to fetch domain health reports.
Health checks are called *tests* in Zonemaster lingo.


## Protocol

This API is implemented using [JSON-RPC 2.0](http://www.jsonrpc.org/specification).

JSON-RPC request objects are accepted in the body of HTTP POST requests to any path.
The HTTP request must contain the header `Content-Type: application/json`.

All JSON-RPC request and response objects have the keys `"jsonrpc"`, `"id"` and `"method"`.
For details on these, refer to the JSON-RPC 2.0 specification.


### Deviations from JSON-RPC 2.0

* The `"jsonrpc"` property is not checked.
* The error code -32603 is used for invalid arguments, as opposed to -32602.
* When standard error codes are used, the accompanying messages are not the standard ones.


### Notes on the JSON-RPC 2.0 implementation

* Extra top-level properties in request objects are allowed but ignored.
* Extra properties in the `"params"` object are allowed for some methods but ignored for others.
* Error messages from the API should be considered sensitive sas they leak details about the internals of the application and the system.
* The error code -32601 is used when the `"method"` property is missing, as opposed to -32600.


## Request handling

When a method expects a string argument but receives an array or an object,
the value may be interpreted as something like `"ARRAY(0x1a2d1d0)"` or `"HASH(0x1a2d2c8)"`.

When a method expects a boolean argument, any kind of value is accepted.
A number of values are interpreted as false: `false`, `null`, `""`, `"0"` and any number equal to zero.
Everything else is interpreted as true.

When a method expects an integer arguments, numbers encoded in strings are also accepted and used transparently,
and numbers with fractions are rounded to the nearest integer.

For details on when a *test* are performed after it's been requested,
see the [architecture documentation](Architecture.md).


## Error reporting

If the request object is invalid JSON, an error with code `-32700` is reported.

If no method is specified or an invalid method is specified, an error with code `-32601` is reported.

All error states that occur after the RPC method has been identified are reported as internal errors with code `-32603`.


## Privilege levels

This API provides three classes of methods:

* *Unrestricted* methods are available to anyone with access to the API.
* *Authenticated* methods have parameters for username and API key credentials.
* *Administrative* methods require that the connection to the API is opened from localhost (`127.0.0.1` or `::1`).


## Data types

This sections describes a number of data types used in this API. Each data type
is based on a JSON data type, but additionally imposes its own restrictions.


### Batch id

Basic data type: number

An positive integer.

The unique id of a *batch*.


### Domain name

Basic data type: string

1. If the string contains characters outside the ASCII character set,
   it must be possible to convert the entire string to the equivalent IDN A-label.

2. If the string is a single character, that character must be `.`.

3. The length of the string must not be greater than 254 characters.

4. When the string is split at `.` characters (after IDNA conversion,
   if needed), each component part must be at most 63 characters long.

5. Each such component part must also consist only of the characters
   `0` to `9`, `a` to `z`, `A` to `Z` and `-`.


### DS info

Basic data type: object

Properties:

* `"digest"`: A string, required. Either 40 or 64 hexadecimal characters (case insensitive).
* `"algorithm"`: An integer, optional.
* `"digtype"`: An integer, optional.
* `"keytag"`: An integer, optional.

Extra properties in *DS info* objects are ignored when present in RPC method arguments, and never returned as part of RPC method results.


### Name server

Basic data type: object

Properties:

* `"ns"`: A *domain name*, required.
* `"ip"`: An IPv4 or IPv6 address, required.


### Priority

Basic data type: number

A higher number means higher priority.


### Profile name

Basic data type: string

The name of a [*profile*](Architecture.md#profile).

One of the strings:

* `"default_profile"`
* `"test_profile_1"`
* `"test_profile_2"`

The `"test_profile_2"` *profile* is identical to `"default_profile"`.

>
> TODO: What is the expected behavior when a *profile* other than the ones listed above is requested?
>


### Progress percentage

Basic data type: number

An integer ranging from 0 (not started) to 100 (finished).


### Severity level

Basic data type: string

One of the strings (in order from least to most severe):

* `"DEBUG"`
* `"INFO"`
* `"NOTICE"`
* `"WARNING"`
* `"ERROR"`
* `"CRITICAL"`


### Test id

Basic data type: string

Each *test* has a unique *test id*.


### Test result

Basic data type: object

The object has three keys, `"module"`, `"message"` and `"level"`.

* `"module"`: a string. The *test module* that produced the result.
* `"message"`: a string. A human-readable *message* describing that particular result.
* `"level"`: a *severity level*. The severity of the message.

Sometimes additional keys are present.

* `"ns"`: a *domain name*. The name server used by the *test module*.

>
> TODO: Can other extra keys in addition to `"ns"` occur here? Can something be said
> about when each extra key is present?
>


### Timestamp

Basic data type: string

>
> TODO: Specify date format
>


## API method: `version_info`

Returns the version of the *Backend*+*Engine* software combination.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "version_info"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "zonemaster_backend": "1.0.7",
    "zonemaster_engine": "v1.0.14"
  }
}
```


#### `"result"`

An object with the following properties:

* `"zonemaster_backend"`: A string. The version number of the running *Web backend*.
* `"zonemaster_engine"`: A string. The version number of the *Engine* used by the *Web backend*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_ns_ips`

Looks up the A and AAAA records for a *domain name* on the public Internet.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "get_ns_ips",
  "params": "zonemaster.net"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": [
    {
      "zonemaster.net": "192.134.4.83"
    },
    {
      "zonemaster.net": "2001:67c:2218:3::1:83"
    }
  ]
}
```


#### `"params"`

A *domain name*. The *domain name* whose IP addresses are to be resolved.


#### `"result"`

A list of one or two objects representing IP addresses (if 2 one is for IPv4 the
other for IPv6). The objects each have a single key and value. The key is the
*domain name* given as input. The value is an IP address for the name, or the
value `0.0.0.0` if the lookup returned no A or AAAA records.

>
> TODO: If the name resolves to two or more IPv4 address, how is that represented?
>

#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_data_from_parent_zone`

Returns all the NS/IP and DS/DNSKEY/ALGORITHM pairs of the domain from the
parent zone.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "get_data_from_parent_zone",
  "params": "zonemaster.net"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "ns_list": [
      {
        "ns": "ns.nic.se",
        "ip": "2001:67c:124c:100a::45"
      },
      {
        "ns": "ns.nic.se",
        "ip": "91.226.36.45"
      },
      ...
    ],
    "ds_list": [
      {
        "algorithm": 5,
        "digtype": 2,
        "keytag": 54636,
        "digest": "cb496a0dcc2dff88c6445b9aafae2c6b46037d6d144e43def9e68ab429c01ac6"
      },
      {
        "keytag": 54636,
        "digest": "fd15b55e0d8ee2b5a8d510ab2b0a95e68a78bd4a",
        "algorithm": 5,
        "digtype": 1
      }
    ]
  }
}
```

>
> Note: The above example response was abbreviated for brevity to only include
> the first two elments in each list. Omitted elements are denoted by a `...`
> symbol.
>


#### `"params"`

A *domain name*. The domain whose DNS records are requested.


#### `"result"`

An object with the following properties:

* `"ns_list"`: A list of *name server* objects representing the nameservers of the given *domain name*.
* `"ds_list"`: A list of *DS info* objects.


>
> TODO: Add wording about what the `"ds_list"` objects represent.
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `start_domain_test`

Enqueues a new *test*.

If an identical *test* was already enqueued and hasn't been started or was enqueued less than 10 minutes earlier,
no new *test* is enqueued.
Instead the id for the already enqueued or run test is returned.

*Tests* enqueud using this method are assigned a *priority* of 10.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "start_domain_test",
  "params": {
    "client_id": "Zonemaster Dancer Frontend",
    "domain": "zonemaster.net",
    "profile": "default_profile",
    "client_version": "1.0.1",
    "nameservers": [
      {
        "ip": "2001:67c:124c:2007::45",
        "ns": "ns3.nic.se"
      },
      {
        "ip": "192.93.0.4",
        "ns": "ns2.nic.fr"
      }
    ],
    "ds_info": [],
    "advanced": true,
    "ipv6": true,
    "ipv4": true
  }
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": "c45a3f8256c4a155"
}
```


#### `"params"`

An object with the following properties:

* `"client_id"`: A free-form string, optional.
* `"domain"`: A *domain name*, required.
* `"profile"`: A *profile name*, optional.
* `"client_version"`: A free-form string, optional.
* `"nameservers"`: A list of *name server* objects, optional.
* `"ds_info"`: A list of *DS info* objects, optional.
* `"advanced"`: A boolean, optional.
* `"ipv6"`: A boolean, optional.
* `"ipv4"`: A boolean, optional.
* `"config"`: A string, optional. The name of a *config profile*.
* `"user_ip"`: A ..., optional.
* `"user_location_info"`: A ..., optional.

>
> TODO: Clarify the data type of the following `"params"` properties:
> `"user_ip"` and `"user_location_info"`.
>
> TODO: Clarify the purpose of each `"params"` property.
>
> TODO: Clarify the default value of each optional `"params"` property.
>


#### `"result"`

A *test id*. The newly started *test*, or a recently run *test* with the same
parameters.
started within the recent configurable short time.

>
> TODO: Specify which configuration option controls the duration of the window
> of *test* reuse.
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `test_progress`

Reports on the progress of a *test*.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "test_progress",
  "params": "c45a3f8256c4a155"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": 100
}
```


#### `"params"`

A *test id*. The *test* to report on.


#### `"result"`

A *progress percentage*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_test_results`

Return all *test result* objects of a *test*, with *messages* in the requested *translation language*.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "get_test_results",
  "params": {
    "id": "c45a3f8256c4a155",
    "language": "en"
  }
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "creation_time": "2016-11-15 11:53:13.965982",
    "id": 25,
    "hash_id": "c45a3f8256c4a155",
    "params": {
      "ds_info": [],
      "client_version": "1.0.1",
      "domain": "zonemaster.net",
      "profile": "default_profile",
      "ipv6": true,
      "advanced": true,
      "nameservers": [
        {
          "ns": "ns3.nic.se",
          "ip": "2001:67c:124c:2007::45"
        },
        {
          "ip": "192.93.0.4",
          "ns": "ns2.nic.fr"
        }
      ],
      "ipv4": true,
      "client_id": "Zonemaster Dancer Frontend"
    },
    "results": [
      {
        "module": "SYSTEM",
        "message": "Using version v1.0.14 of the Zonemaster engine.\n",
        "level": "INFO"
      },
      {
        "message": "Configuration was read from DEFAULT CONFIGURATION\n",
        "level": "INFO",
        "module": "SYSTEM"
      },
      ...
    ]
  }
}
```

>
> Note: The above example response was abbreviated for brevity to only include
> the first two elments in each list. Omitted elements are denoted by a `...`
> symbol.
>


#### `"params"`

An object with the following properties:

* `"id"`: A *test id*, required.
* `"language"`: A string, required. Must be at least two characters long. The
  two first characters are used to look up the *translation language* to be
  used. If the lookup fails, the choice defaults to English.


#### `"result"`

An object with a the following properties:

* `"creation_time"`: A *timestamp*. The time at which the *test* was enqueued.
* `"id"`: An integer.
* `"hash_id"`: A string.
* `"params"`: The `"params"` object sent to `start_domain_test` when the *test*
  was started.
* `"results"`: A list of *test result* objects.

>
> TODO: Specify the MD5 hash format.
>
> TODO: What about if the Test was created with `add_batch_job` or something
> else?
>
> TODO: It's confusing that the method is named `"start_domain_test"`, when
> it doesn't actually start the *test*.
>



#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_test_history`

Returns a list of completed *tests* for a domain.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "get_test_history",
  "params": {
    "offset": 0,
    "limit": 200,
    "frontend_params": {
      "client_id": "Zonemaster Dancer Frontend",
      "domain": "zonemaster.net",
      "profile": "default_profile",
      "client_version": "1.0.1",
      "nameservers": [
        {
          "ns": "ns3.nic.se",
          "ip": "2001:67c:124c:2007::45"
        },
        {
          "ns": "ns2.nic.fr",
          "ip": "192.93.0.4"
        }
      ],
      "ds_info": [],
      "advanced": true,
      "ipv6": true,
      "ipv4": true
    }
  }
}
```

Example response:
```json
{
  "id": 7,
  "jsonrpc": "2.0",
  "result": [
    {
      "id": "c45a3f8256c4a155",
      "creation_time": "2016-11-15 11:53:13.965982",
      "overall_result": "error",
      "advanced_options": null
    },
    {
      "id": "32dd4bc0582b6bf9",
      "creation_time": "2016-11-14 08:46:41.532047",
      "overall_result": "error",
      "advanced_options": null
    },
    ...
  ]
}
```

>
> Note: The above example response was abbreviated for brevity to only include
> the first two elments in each list. Omitted elements are denoted by a `...`
> symbol.
>


#### `"params"`

An object with the following properties:

* `"offset"`: An integer, optional. (default: 0).
* `"limit"`: An integer, optional. (default: 200).
* `"frontend_params"`: As described below.

The value of `"frontend_params"` is an object in turn, with the
keys `"domain"` and `"nameservers"`. `"domain"` and `"nameservers"`
will be used to look up all tests for the given domain, separated
according to if they were started with a `"nameservers"` parameter or
not.

>
> TODO: Do we have an SQL injection opportunity here?
>
> TODO: Describe the remaining keys in the example
>
> TODO: Describe the purpose of `"offset"` and `"limit"`
>
> TODO: Is the `"nameservers"` value a boolean in disguise?
>
> TODO: The description of `"frontend_params"` is clearly not up to date. Can it
> be described in a better way?
>


#### `"result"`

An object with the following properties:

* `"id"` A *test id*.
* `"creation_time"`: A *timestamp*. Time when the Test was enqueued.
* `"advanced_options"`: A string or `null`. `"1"` if the `"advanced"` flag was set in the method call to `start_domain_test` that created this Test.
* `"overall_result"`: A string. The most severe problem level logged in the test results.

>
> TODO: Describe the format of `"overall_result"`.
>
> TODO: What about if the *test* was created with `add_batch_job` or something else?
>
> TODO: What about if the *test* was created with `"advanced"` set to `false` in `start_domain_test`?
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `add_api_user`

>
> TODO: Method description.
>

This method requires the *administrative* *privilege level*.

Example request:
```json
{
  "jsonrpc": "2.0",
  "method": "add_api_user",
  "id": 4711,
  "params": {
    "username": "citron",
    "api_key": "fromage"
  }
}
```

Example response:
```json
{
  "id": 4711,
  "jsonrpc": "2.0",
  "result": 0
}
```


#### `"params"`

An object with the following properties:

* `"username"`: A string, optional. The name of the user to add.
* `"api_key"`: A string, optional. The API key (in effect, password) for the user to add.

>
> TODO: Are `"username"` and `"api_key"` really supposed to be optional? Because
> they are now, is that a bug? I get `"result": 0` when I omit them. I would
> have expected parameter validation errors.
>


#### `"result"`

An integer.

>
> TODO: Describe the possible values of the result and what they mean.
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `add_batch_job`

>
> TODO: Method description.
>

All the domains will be tested using identical parameters.

If an identical *test* for a domain was already enqueued and hasn't been started or was enqueued less than 10 minutes earlier,
no new *test* is enqueued for this domain.

*Tests* enqueud using this method are assigned a *priority* of 5.


Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 147559211348450,
  "method": "add_batch_job",
  "params" : {
    "api_key": "fromage",
    "username": "citron",
    "test_params": {},
    "domains": [
      "zonemaster.net",
      "domain1.se",
      "domain2.fr"
    ]
  }
}
```

Example response:
```json
{
    "jsonrpc": "2.0",
    "id": 147559211348450,
    "result": 8
}
```


#### `"params"`

An object with the following properties:

* `"username"`: A string. The username of this batch.
* `"api_key"`: A string. The api_key associated with the username username of this *batch*.
* `"domains"`: A list of *domain names*. The domains to be tested.
* `"test_params"`: As described below.

The value of `"test_params"` is an object with the following properties:

* `"client_id"`: A free-form string, optional.
* `"profile"`: A *profile name*, optional.
* `"client_version"`: A free-form string, optional.
* `"nameservers"`: A list of *name server* objects, optional.
* `"ds_info"`: A list of *DS info* objects, optional.
* `"advanced"`: A boolean, optional.
* `"ipv6"`: A boolean, optional.
* `"ipv4"`: A boolean, optional.
* `"config"`: A string, optional. The name of a *config profile*.
* `"user_ip"`: A ..., optional.
* `"user_location_info"`: A ..., optional.

>
> TODO: Clarify the data type of the following `"frontend_params"` properties:
> `"user_ip"` and `"user_location_info"`.
>
> TODO: Clarify which `"params"` and `"frontend_params"` properties are optional
> and which are required.
>
> TODO: Clarify the default value of each optional `"params"` and
> `"frontend_params"` property.
>
> TODO: Clarify the purpose of each `"params"` and `"frontend_params"` property.
>
> TODO: Are domain names actually validated in practice?
>


#### `"result"`

A *batch id*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_batch_job_result`

>
> TODO: Method description.
>

Example request:
```json
{
    "jsonrpc": "2.0",
    "id": 147559211994909,
    "method": "get_batch_job_result",
    "params": "8"
}
```

Example response:
```json
{
   "jsonrpc": "2.0",
   "id": 147559211994909,
   "result": {
      "nb_finished": 5,
      "finished_test_ids": [
         "43b408794155324b",
         "be9cbb44fff0b2a8",
         "62f487731116fd87",
         "692f8ffc32d647ca",
         "6441a83fcee8d28d"
      ],
      "nb_running": 195
   }
}
```


#### `"params"`

A *batch id*.


#### `"result"`

An object with the following properties:

* `"nb_finished"`: an integer. The number of finished tests.
* `"nb_running"`: an integer. The number of running tests.
* `"finished_test_ids"`: a list of *test ids*. The set of finished *tests* in this *batch*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `validate_syntax`

Checks the `"params"` structure for syntax coherence. It is very strict on what
is allowed and what is not to avoid any SQL injection and cross site scripting
attempts. It also checks the domain name for syntax to ensure the domain name
seems to be a valid domain name and a test by the *Engine* can be started.

Example request:
```json
{
    "jsonrpc": "2.0",
    "id": 143014426992009,
    "method": "validate_syntax",
    "params": {
        "domain": "zonemaster.net",
        "ipv6": 1,
        "ipv4": 1,
        "nameservers": [
            {
                "ns": "ns1.nic.fr",
                "ip": "1.2.3.4"
            },
            {
                "ns": "ns2.nic.fr",
                "ip": "192.134.4.1"
            }
        ]
    }
}
```

Example response:
```json
{
    "jsonrpc": "2.0",
    "id": 143014426992009,
    "result": {
        "status": "ok",
        "message": "Syntax ok"
    }
}
```


#### `"params"`

An object with the following properties:

* `"domain"`: a *domain name*.
* `"ipv4"`: an optional `1`, `0`, `true` or `false`.
* `"ipv6"`: an optional `1`, `0`, `true` or `false`.
* `"ds_info"`: an optional list of *DS info* objects.
* `"nameservers"`: an optional list of objects each of *name server* objects.
* `"profile"`: an optional *profile name*.
* `"advanced"`: an optional `true` or `false`.
* `"client_id"`: ...
* `"client_version"`: ...
* `"user_ip"`: ...
* `"user_location_info"`: ...
* `"config"`: ...

If the `"nameservers"` key is _not_ set, a recursive query made by the
server to its locally configured resolver for NS records for the
value of the `"domain"` key must return a reply with at least one
resource record in the Answer Section.

At least one of `"ipv4"` and `"ipv6"` must be present and either `1` or `true`.

>
> TODO: Clarify the data type of the following `"params"` properties:
> `"client_id"`, `"client_version"`, `"user_ip"`, `"user_location_info"` and
> `"config"`.
>
> TODO: Clarify the purpose of each `"params"` property.
>


#### `"result"`

An object with the following properties:

* `"status"`: either `"ok"` or `"nok"`.
* `"message"`: a string. Human-readable details about the status.

#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_test_params`

>
> TODO: Method description
>
> TODO: Example request
>
> TODO: Example response
>


#### `"params"`

A *test id*.


#### `"result"`

The `"params"` object sent to `start_domain_test` when the *test* was started.

>
> TODO: What about if the *test* was created with `add_batch_job` or something else?
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

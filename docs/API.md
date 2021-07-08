# API

## Purpose

This document describes the JSON-RPC API provided by the Zonemaster *RPC API daemon*.
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
* The error code -32603 is used for invalid arguments, as opposed to the dedicated error code -32602.
* When standard error codes are used, the accompanying messages are not the standard ones.


### Notes on the JSON-RPC 2.0 implementation

* Extra top-level properties in request objects are allowed but ignored.
* No extra properties are allowed in the `"params"` object.
* Error messages from the API should be considered sensitive as they sometimes leak details about the internals of the application and the system.
* The error code -32601 is used when the `"method"` property is missing, rather than the perhaps expected error code -32600.


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

If no `params` object is specified when it is required, or the `params` object
for the specified method is invalid, an error with code `-32602` is reported.
For more information on the validation error data format see
[Validation error data].

All error states that occur after the RPC method has been identified are reported as internal errors with code `-32603`.


## Privilege levels

This API provides three classes of methods:

* *Unrestricted* methods are available to anyone with access to the API.
* *Authenticated* methods have parameters for username and API key credentials.
* *Administrative* methods require that the connection to the API is opened from localhost (`127.0.0.1` or `::1`).


## Data types

This sections describes a number of data types used in this API. Each data type
is based on a JSON data type, but additionally imposes its own restrictions.


### API key

Basic data type: string

A string of alphanumerics, hyphens (`-`) and underscores (`_`), of at least 1
and at most 512 characters.
I.e. a string matching `/^[a-zA-Z0-9-_]{1,512}$/`.

Represents the password of an authenticated account (see *[Privilege levels]*)


### Batch id

Basic data type: number

A strictly positive integer.

The unique id of a *batch*.


### Client id

Basic data type: string

A string of alphanumerics, hyphens, underscores, pluses (`+`), tildes (`~`),
full stops (`.`), colons (`:`) and spaces (` `), of at least 1 and at most 50
characters.
I.e. a string matching `/^[a-zA-Z0-9-+~_.: ]{1,50}$/`.

Represents the name of the client.
Used for monitoring which client (GUI) uses the API.


### Client version

Basic data type: string

A string of alphanumerics, hyphens, pluses, tildes, underscores, full stops,
colons and spaces, of at least 1 and at most 50 characters.
I.e. a string matching `/^[a-zA-Z0-9-+~_.: ]{1,50}$/`.

Represents the version of the client.
Used for monitoring which client (GUI) uses the API.


### Domain name

Basic data type: string

1. If the string is a single character, that character must be `.`.

2. The length of the string must not be greater than 254 characters.

3. When the string is split at `.` characters (after IDNA conversion,
   if needed), each component part must be at most 63 characters long.

> Note: Currently there are no restrictions on what characters that are allowed.


### DS info

Basic data type: object

DS for [Delegation Signer](https://tools.ietf.org/html/rfc4034) references DNSKEY-records in the sub-delegated zone.

Properties:
* `"digest"`: A string, required. Either 40, 64 or 96 hexadecimal characters (case insensitive).
* `"algorithm"`: An non negative integer, required.
* `"digtype"`: An non negative integer, required.
* `"keytag"`: An non negative integer, required.


### IP address

Basic data type: string

This parameter is a string that is either
 - a valid IPv4 in [dot-decimal notation] ;
 - a valid IPv6 in [recommend text format for IPv6 addresses].

### Language tag

Basic data type: string

A string matching one of the following regular expression:
* `/^[a-z]{2}$/`, preferred format.
* `/^[a-z]{2}_[A-Z]{2}$/`, **deprecated** format, use the preferred format instead.

The set of valid *language tags* is further constrained by the
[LANGUAGE.locale] property.
* If the *language tag* is a five character string, it needs to match a *locale
  tag* in [LANGUAGE.locale].
* If the *language tag* is a two-character string, it needs to match the
  first two characters of exactly one *locale tag* in [LANGUAGE.locale].
  (So that it is unambiguous which *locale tag* is matched.)

E.g. if [LANGUAGE.locale] is "en_US en_UK sv_SE", all the valid *language tags*
are "en_US", "en_UK", "sv_SE" and "sv".

The use of `language tags` that include the country code is *deprecated*.

#### Design

The two first characters of the *language tag* are intended to be an
[ISO 639-1] two-character language code and the optional two last characters
are intended to be an [ISO 3166-1 alpha-2] two-character country code.

#### Out-of-the box support

A default installation will accept the following *language tags*:

Language | Preferred language tag | Deprecated language tag
---------|------------------------|------------------
Danish   | da                     | da_DK
English  | en                     | en_US
Finnish  | fi                     | fi_FI
French   | fr                     | fr_FR
Norwegian| nb                     | nb_NO
Swedish  | sv                     | sv_SE


### Name server

Basic data type: object

Properties:

* `"ns"`: A *domain name*, required.
* `"ip"`: An *IP address* (IPv4 or IPv6), optional. (default: unset)


### Non-negative integer

Basic data type: number (integer)

A non-negative integer is either zero or strictly positive.


### Priority

Basic data type: number (integer)

This parameter is any integer that will be used by The Zonemaster Test Agents to sort the test requests from highest to lowest priority.
This parameter will typically be used in a setup where a GUI will send requests to the RPC API and would like to get response as soon as possible while at the same time using the idle time for background batch testing.
The drawback of this setup will be that the GUI will have to wait for at least one background processing slot to become free (would be a few secods in a typical installation with up to 30 parallel zonemaster processes allowed)

### Profile name

Basic data type: string

This parameter is a case-insensitive string validated with the case-insensitive
regex `/^[a-z0-9]$|^[a-z0-9][a-z0-9_-]{0,30}[a-z0-9]$/i`.

The name of a [*profile*](Architecture.md#profile).

### Progress percentage

Basic data type: number (integer)

An integer ranging from 0 (not started) to 100 (finished).


### Queue

Basic data type: number (integer)

This parameter allows an optional separation of testing in the same database. The default value for the queue is 0. It is closely related to the *lock_on_queue* parameter of the [ZONEMASTER] section of the backend_config.ini file.
The typical use case for this parameter would be a setup with several separate Test Agents running on separate physical or virtual machines each one dedicated to a specific task, for example queue 0 for frontend tests and queue 1 dedicated to batch testing. Running several Test Agents on the same machine is currently not supported.


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

A string of exactly 16 lower-case hex-digits matching `/^[0-9a-f]{16}$/`.

Each *test* has a unique *test id*.


### Test result

Basic data type: object

The object has three keys, `"module"`, `"message"` and `"level"`.

* `"module"`: a string. The *test module* that produced the result.
* `"message"`: a string. A human-readable *message* describing that particular result.
* `"level"`: a *severity level*. The severity of the message.

Sometimes additional keys are present.

* `"ns"`: a *domain name*. The name server used by the *test module*.
This key is added when the module name is `"NAMESERVER"`.


### Timestamp

Basic data type: string

Default database timestamp format: "Y-M-D H:M:S.ms".
Example: "2017-12-18 07:56:17.156939"

### Username

Basic data type: string

A string of alphanumerics, dashes, full stops and at-signs, of at least 1 and at
most 50 characters.
I.e. a string matching `/^[a-zA-Z0-9-.@]{1,50}$/`.

Represents the name of an authenticated account (see *[Privilege levels]*)

### Validation error data

Basic data type: array

The items of the array are objects with two keys, `"path"` and `"message"`:
* `"path"`: a string. A [JSON Pointer] to an element in the request's param
  object. E.g.: `"/nameservers/0/ip"`.
* `"message"`: a string. The error message associated with the element
  referenced by `"path"`.


## API method: `version_info`

Returns the version of the Zonemaster Backend and Zonemaster Engine software combination

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

* `"zonemaster_backend"`: A string. The version number of the running *Zonemaster Backend*.
* `"zonemaster_engine"`: A string. The version number of the *Zonemaster Engine* used by the *RPC API daemon*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `profile_names`

Returns the names of the public subset of the [available profiles].

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "profile_names"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": [
    "default",
    "another-profile"
  ]
}
```


#### `"result"`

An array of *Profile names* in lower case. `"default"` is always included.


## API method: `get_language_tags`

Returns the set of valid [*language tags*][Language tag].

> Note: If there are two [*locale tags*][LANGUAGE.locale] in [LANGUAGE.locale]
> that would give the same [short language tag][Language tag] then the short tag
> is excluded from the set of valid [*language tags*][Language tag].
>
> Note: Language tags that include country code are *deprecated*.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "get_language_tags"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": [
    "da",
    "da_DK",
    "en",
    "en_US",
    "fi",
    "fi_FI",
    "fr",
    "fr_FR",
    "nb",
    "nb_NO",
    "sv",
    "sv_SE"
  ]
}
```


#### `"result"`

An array of *language tags*. It is never empty.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for
> clients to know how react to them. Or prevent RPCAPI from starting with
> errors in the configuration file and make it not to reread the configuration
> file while running.
>


## API method: `get_host_by_name`

Looks up the A and AAAA records for a hostname (*domain name*) on the public Internet.

Example request:

*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "get_host_by_name",
  "params": {"hostname": "zonemaster.net"}
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

An object with the properties:

* `"hostname"`: A *domain name*, required. The hostname whose IP addresses are to be resolved.
* `"language"`: A [Language Tag], optional, used for validation error messages
  translation, the default value is defined in the [language section]
  of the configuration.


#### `"result"`

A list of one or two objects representing IP addresses (if 2 one is for IPv4 the
other for IPv6). The objects each have a single key and value. The key is the
*domain name* given as input. The value is an IP address for the name, or the
value `0.0.0.0` if the lookup returned no A or AAAA records.

>
> TODO: If the name resolves to two or more IPv4 address, how is that represented?
>


#### `"error"`

* If any parameter fails to be validated an error code of -32602 is returned. The `data` properties contains an array of all error, see [Validation error data].

  Example of error response:

```json
{
  "error": {
    "message": "Invalid method parameter(s).",
    "code": "-32602",
    "data": [
      {
        "path": "/hostname",
        "message": "Missing property"
      }
    ]
  },
  "jsonrpc": "2.0",
  "id": 1624630143271
}
```

## API method: `get_data_from_parent_zone`

Returns all the NS/IP and DS/DNSKEY/ALGORITHM pairs of the domain from the
parent zone.

Example request:
*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "get_data_from_parent_zone",
  "params": {"domain": "zonemaster.net"}
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

An object with the properties:

* `"domain"`: A *domain name*, required. The domain whose DNS records are requested.
* `"language"`: A [Language Tag], optional, used for validation error messages
  translation, the default value is defined in the [language section]
  of the configuration.

#### `"result"`

An object with the following properties:

* `"ns_list"`: A list of [*name server*][Name server] objects representing the nameservers of the given *domain name*.
* `"ds_list"`: A list of [*DS info*][DS info] objects representing delegation signer (DS record data) of the given *domain name*.


#### `"error"`

* If any parameter fails to be validated an error code of -32602 is returned. The `data` properties contains an array of all error, see [Validation error data].

  Example of error response:

```json
{
  "error": {
    "data": [
      {
        "message": "The domain name character(s) are not supported",
        "path": "/domain"
      }
    ],
    "code": "-32602",
    "message": "Invalid method parameter(s)."
  },
  "id": 1624630143271,
  "jsonrpc": "2.0"
}
```


## API method: `start_domain_test`

Enqueues a new *test*.

If an identical *test* was already enqueued and hasn't been started or was enqueued less than 10 minutes earlier,
no new *test* is enqueued.
Instead the id for the already enqueued or run test is returned.

*Tests* enqueued using this method are assigned a *priority* of 10.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "start_domain_test",
  "params": {
    "client_id": "Zonemaster Dancer Frontend",
    "domain": "zonemaster.net",
    "profile": "default",
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

* `"domain"`: A *domain name*, required. The zone to test.
* `"ipv6"`: A boolean, optional. (default: [`net.ipv4`][net.ipv4] profile value). Used to enable or disable testing over IPv4 transport protocol.
* `"ipv4"`: A boolean, optional. (default: [`net.ipv6`][net.ipv6] profile value). Used to enable or disable testing over IPv6 transport protocol.
* `"nameservers"`: A list of [*name server*][Name server] objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"ds_info"`: A list of [*DS info*][DS info] objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"profile"`: A *profile name*, optional. (default: `"default"`). Run the tests using the given profile.
* `"client_id"`: A *client id*, optional. (default: unset). Used to monitor which client uses the API.
* `"client_version"`: A *client version*, optional. (default: unset). Used to monitor which client use the API
* `"priority"`: A *priority*, optional. (default: `10`)
* `"queue"`: A *queue*, optional. (default: `0`)
* `"language"`: A [Language Tag], optional, used for validation error messages
  translation, the default value is defined in the [language section]
  of the configuration.

> TODO: Clarify the purpose of each `"params"` property.
>


#### `"result"`

A *test id*.

If the test has been run with the same domain name within an interval of 10 minutes (hard coded),
then the new request does not trigger a new test, but returns with the results of the last test


#### `"error"`

* If any parameter is invalid an error code of -32602 is returned. The `data` property contains an array of all errors, see [Validation error data].

  Example of error response:

```json
{
  "error": {
    "code": "-32602",
    "data": [
      {
        "message": "Expected integer - got string.",
        "path": "/ds_info/0/algorithm"
      },
      {
        "message": "Missing property.",
        "path": "/ds_info/0/digest"
      },
      {
        "path": "/profile",
        "message": "Unknown profile"
      },
      {
        "path": "/domain",
        "message": "The domain name character(s) are not supported"
      },
      {
        "path": "/nameservers/0/ip",
        "message": "Invalid IP address"
      }
    ],
    "message": "Invalid method parameter(s)."
  },
  "id": 1,
  "jsonrpc": "2.0"
}
```

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `test_progress`

Reports on the progress of a *test*.

Example request:

*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "test_progress",
  "params": {"test_id": "c45a3f8256c4a155"}
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

An object with the property:

`"test_id"`: A *test id*, required. The *test* to report on.


#### `"result"`

A *progress percentage*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_test_results`

Return all *test result* objects of a *test*, with *messages* in the requested language as selected by the
*language tag*.

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

The `id` parameter must match the `result` in the response to a `start_domain_test` call,
and that test must have been completed.

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
      "profile": "default",
      "ipv6": true,
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
* `"language"`: A *language tag*, required.


#### `"result"`

There are two different results depending on the test creation method:

In the case of a test created with `start_domain_test`:

* `"creation_time"`: A *timestamp*. The time at which the *test* was enqueued.
* `"id"`: An integer.
* `"hash_id"`: A *test id*. The *test* in question.
* `"params"`: A normalized version `"params"` object sent to
  `start_domain_test` when the *test* was started.
* `"results"`: A list of *test result* objects.


In the case of a test created with `add_batch_job`:
* `"creation_time"`: A *timestamp*. The time at which the *test* was enqueued.
* `"id"`: An integer.
* `"hash_id"`: A *test id*. The *test* in question.
* `"params"`: A normalized version `"params"` object sent to `add_batch_job`
  when the *test* was started.
* `"results"`: the result is a list of *test id* corresponding to each tested
  domain.

>
> TODO: Change name in the API of `"hash_id"` to `"test_id"`
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
    "filter": "all",
    "frontend_params": {
      "domain": "zonemaster.net"
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
    },
    {
      "id": "32dd4bc0582b6bf9",
      "creation_time": "2016-11-14 08:46:41.532047",
      "overall_result": "error",
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

* `"offset"`: A *non-negative integer*, optional. (default: 0). Position of the first returned element from the database returned list.
* `"limit"`: A *non-negative integer*, optional. (default: 200). Number of element returned from the *offset* element.
* `"filter"`: A string, one of `"all"`, `"delegated"` and `"undelegated"`, optional. (default: `"all"`)
* `"frontend_params"`: An object, required.

The value of "frontend_params" is an object with the following properties:

* `"domain"`: A *domain name*, required.


#### `"result"`

An object with the following properties:

* `"id"` A *test id*.
* `"creation_time"`: A *timestamp*. Time when the Test was enqueued.
* `"overall_result"`: A string. The most severe problem level logged in the test results.
It could be:
    * `"ok"`, all is normal
    * `"warning"`, equivalent to the `"WARNING"` *severity level*.
    * `"error"`, equivalent to the `"ERROR"` *severity level*.
    * `"critical"`, equivalent to the `"CRITICAL"` *severity level*.


> TODO: What about if the *test* was created with `add_batch_job` or something else?


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `add_api_user`

In order to use advanced api features such as the *batch test*, it's necessaire to previously create an api key.
This key can be obtained with the creation of a user in the system.
This function allow the creation of a new user and so, the creation of a new api key.

Add a new *user*

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
  "result": 1
}
```


#### `"params"`

An object with the following properties:

* `"username"`: An *username*, required. The name of the user to add.
* `"api_key"`: An *api key*, required. The API key for the user to add.


#### `"result"`

An integer. The value is equal to 1 if the registration is a success, or 0 if it failed.


#### `"error"`
>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

Trying to add a already existing user:
```json
{
  "code": -32603,
  "message": "User already exists\n"
}
```

Ommitting params:
```json
{
  "message": "username or api_key not provided to the method add_api_user\n",
  "code": -32603
}
```


## API method: `add_batch_job`

Add a run a new *batch test* composed by a set of *domain name* and a *params* object.
All the domains will be tested using identical parameters.

An *api user* can only have one un-finished *batch* at a time.

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

* `"username"`: An *username*, required. The name of the account of an authorized user.
* `"api_key"`: An *api key*, required. The api_key associated with the username.
* `"domains"`: A list of *domain names*, required. The domains to be tested.
* `"test_params"`: As described below, optional. (default: `{}`)

The value of `"test_params"` is an object with the following properties:

* `"client_id"`: A *client id*, optional. (default: unset)
* `"profile"`: A *profile name*, optional (default: `"default"`). Run the tests using the given profile.
* `"client_version"`: A *client version*, optional. (default: unset)
* `"nameservers"`: A list of [*name server*][Name server] objects, optional. (default: `[]`)
* `"ds_info"`: A list of [*DS info*][DS info] objects, optional. (default: `[]`)
* `"ipv6"`: A boolean, optional. (default: [`net.ipv4`][net.ipv4] profile value).
* `"ipv4"`: A boolean, optional. (default: [`net.ipv6`][net.ipv6] profile value).
* `"priority"`: A *priority*, optional. (default: `5`)
* `"queue"`: A *queue*, optional. (default: `0`)


#### `"result"`

A *batch id*.


#### `"error"`

* You can't create a new batch job.
  A *batch* with unfinished *tests* already exists for this *api user*.
* If the given `profile` is not among the [available profiles], a user
  error is returned.


>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


## API method: `get_batch_job_result`

Return all *test id* objects of a *batch test*, with the number of finshed *test*.

Example request:

*Valid syntax:*
```json
{
    "jsonrpc": "2.0",
    "id": 147559211994909,
    "method": "get_batch_job_result",
    "params": {"batch_id": "8"}
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

An object with the property:

* `"batch_id"`: A *batch id*, required.


#### `"result"`

An object with the following properties:

* `"nb_finished"`: a *non-negative integer*. The number of finished tests.
* `"nb_running"`: a *non-negative integer*. The number of running tests.
* `"finished_test_ids"`: a list of *test ids*. The set of finished *tests* in this *batch*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

## API method: `get_test_params`

Return a normalized *params* objects of a *test*.

Example request:

*Valid syntax:*
```json
{
    "jsonrpc": "2.0",
    "id": 143014426992009,
    "method": "get_test_params",
    "params": {"test_id": "6814584dc820354a"}
}
```

Example response:
```json
{
    "jsonrpc": "2.0",
    "id": 143014426992009,
    "result": {
         "domain": "zonemaster.net",
         "profile": "default",
         "client_id": "Zonemaster Dancer Frontend",
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
         "ipv6": true,
         "client_version": "1.0.1",
         "ds_info": []
    }
}
```


#### `"params"`

An object with the property:

* `"test_id"`: A *test id*, required.


#### `"result"`

The `"params"` object sent to `start_domain_test` or `add_batch_job` when the *test* was started.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

[Available profiles]:           Configuration.md#profiles-section
[DS info]:                      #ds-info
[ISO 3166-1 alpha-2]:           https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
[ISO 639-1]:                    https://en.wikipedia.org/wiki/ISO_639-1
[LANGUAGE.locale]:              Configuration.md#locale
[Language tag]:                 #language-tag
[Validation error data]:        #validation-error-data
[Dot-decimal notation]:         https://en.wikipedia.org/wiki/Dot-decimal_notation
[Recommend text format for IPv6 addresses]: https://datatracker.ietf.org/doc/html/rfc5952
[JSON Pointer]:                 https://datatracker.ietf.org/doc/html/rfc6901
[Name server]:                  #name-server
[net.ipv4]:                     https://metacpan.org/pod/Zonemaster::Engine::Profile#net.ipv4
[net.ipv6]:                     https://metacpan.org/pod/Zonemaster::Engine::Profile#net.ipv6
[Privilege levels]:             #privilege-levels
[language section]:             Configuration.md#usage

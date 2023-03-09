# API

## Table of contents

* [Purpose](#purpose)
* [Protocol](#protocol)
  * [Deviations from JSON-RPC 2.0](#deviations-from-json-rpc-20)
  * [Notes on the JSON-RPC 2.0 implementation](#notes-on-the-json-rpc-20-implementation)
* [Request handling](#request-handling)
* [Error reporting](#error-reporting)
* [Privilege levels](#privilege-levels)
* [Data types](#data-types)
  * [API key](#api-key)
  * [Batch id](#batch-id)
  * [Client id](#client-id)
  * [Client version](#client-version)
  * [Domain name](#domain-name)
  * [DS info](#dS-info)
  * [IP address](#ip-address)
  * [Language tag](#language-tag)
  * [Name server](#name-server)
  * [Non-negative integer](#non-negative-integer)
  * [Priority](#priority)
  * [Profile name](#profile-name)
  * [Progress percentage](#progress-percentage)
  * [Queue](#queue)
  * [Severity level](#severity-level)
  * [Test id](#test-id)
  * [Test result](#test-result)
  * [Job id](#job-id)
  * [Job result](#job-result)
  * [Timestamp (deprecated)](#timestamp-deprecated)
  * [Timestamp](#timestamp)
  * [Username](#username)
* [API methods](#api-methods)
  * [API method: system_versions](#api-method-system_versions)
  * [API method: conf_profiles](#api-method-conf_profiles)
  * [API method: conf_languages](#api-method-conf_languages)
  * [API method: lookup_address_records](#api-method-lookup_address_records)
  * [API method: lookup_delegation_data](#api-method-lookup_delegation_data)
  * [API method: job_create](#api-method-job_create)
  * [API method: job_status](#api-method-job_status)
  * [API method: job_results](#api-method-job_results)
  * [API method: job_params](#api-method-job_params)
  * [API method: domain_history](#api-method-domain_history)
    * [Undelegated and delegated](#undelegated-and-delegated)
  * [API method: user_create](#api-method-user_create)
  * [API method: batch_create](#api-method-batch_create)
  * [API method: batch_status](#api-method-batch_status)
* [Deprecated](#deprecated)
  * [API method: version_info](#api-method-version_info)
  * [API method: profile_names](#api-method-profile_names)
  * [API method: get_language_tags](#api-method-get_language_tags)
  * [API method: get_host_by_name](#api-method-get_host_by_name)
  * [API method: get_data_from_parent_zone](#api-method-get_data_from_parent_zone)
  * [API method: start_domain_test](#api-method-start_domain_test)
  * [API method: test_progress](#api-method-test_progress)
  * [API method: get_test_results](#api-method-get_test_results)
  * [API method: get_test_history](#api-method-get_test_history)
  * [API method: add_api_user](#api-method-add_api_user)
  * [API method: add_batch_job](#api-method-add_batch_job)
  * [API method: get_batch_job_result](#api-method-get_batch_job_result)
  * [API method: get_test_params](#api-method-get_test_params)


## Purpose

This document describes the JSON-RPC API provided by the Zonemaster *RPC API daemon*.
This API provides means to check the health of domains and to fetch domain health reports.
Health checks are called *tests* in Zonemaster lingo.


## Protocol

This API is implemented using [JSON-RPC 2.0].

JSON-RPC request objects are accepted in the body of HTTP POST requests to any path.
The HTTP request must contain the header `Content-Type: application/json`.

All JSON-RPC request and response objects have the keys `"jsonrpc"`, `"id"` and `"method"`.
For details on these, refer to the [JSON-RPC 2.0] specification.


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
* *Authenticated* methods have parameters for [*username*][Username] and [*api key*][API key]
  credentials.
* *Administrative* methods require that the connection to the API is opened from
  localhost (`127.0.0.1` or `::1`).


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

DS for [Delegation Signer] references a DNSKEY record in the delegated zone.

Properties:
* `"digest"`: A string, required. Either 40, 64 or 96 hexadecimal characters (case insensitive).
* `"algorithm"`: An non negative integer, required.
* `"digtype"`: An non negative integer, required.
* `"keytag"`: An non negative integer, required.


### IP address

Basic data type: string

This parameter is a string that is either
 - a valid IPv4 address in [dot-decimal notation] ;
 - a valid IPv6 address in [recommended text format][RFC 5952] for IPv6 addresses.

### Language tag

Basic data type: string

A string matching one of the following regular expression:
* `/^[a-z]{2}$/`, preferred format.
* `/^[a-z]{2}_[A-Z]{2}$/`, **deprecated** format, use the preferred format instead
  (planned removal: v2023.1).

The set of valid *language tags* is further constrained by the
[`LANGUAGE.locale`][LANGUAGE.locale] property.
* If the *language tag* is a five character string, it needs to match a *locale
  tag* in [`LANGUAGE.locale`][LANGUAGE.locale].
* If the *language tag* is a two-character string, it needs to match the
  first two characters of exactly one *locale tag* in [`LANGUAGE.locale`][LANGUAGE.locale].
  (So that it is unambiguous which *locale tag* is matched.)

E.g. if [`LANGUAGE.locale`][LANGUAGE.locale] is "en_US en_UK sv_SE", all the valid *language tags*
are "en_US", "en_UK", "sv_SE" and "sv".

The use of `language tags` that include the country code is *deprecated* (planned
removal: v2023.1).

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
Spanish  | es                     | es_ES
Finnish  | fi                     | fi_FI
French   | fr                     | fr_FR
Norwegian| nb                     | nb_NO
Swedish  | sv                     | sv_SE


### Name server

Basic data type: object

Properties:

* `"ns"`: A [*domain name*][Domain name], required.
* `"ip"`: An [*IP address*][IP address] (IPv4 or IPv6), optional. (default: unset)


### Non-negative integer

Basic data type: number (integer)

A non-negative integer is either zero or strictly positive.


### Priority

Basic data type: number (integer)

This parameter is any integer that will be used by The Zonemaster Test Agents to sort the test requests from highest to lowest priority.
This parameter will typically be used in a setup where a GUI will send requests to the RPC API and would like to get response as soon as possible while at the same time using the idle time for background batch testing.
The drawback of this setup will be that the GUI will have to wait for at least one background processing slot to become free (would be a few seconds in a typical installation with up to 30 parallel zonemaster processes allowed)

### Profile name

Basic data type: string

This parameter is a case-insensitive string validated with the case-insensitive
regex `/^[a-z0-9]$|^[a-z0-9][a-z0-9_-]{0,30}[a-z0-9]$/i` which must be predefined
in the configuration file as specified in the Configuration document
[profile sections].

The name of a [*profile*](Architecture.md#profile).

Below are the current error messages for an incorrect *profile name*. The
messages should, however, considered to be unstable and are planned to be updated
to gain consistent error messages from the RPCAPI.

When a method receives an illegal *profile name* value for a parameter with this
type, it returns the following error message:

```json
{
    "jsonrpc":"2.0",
    "id":1,
    "error":{
        "message":"Invalid method parameter(s).",
        "data": [
            {
              "path": "/profile",
              "message": "String does not match (?^ui:^[a-z0-9]$|^[a-z0-9][a-z0-9_-]{0,30}[a-z0-9]$)."
            },
        ],
        "code":"-32602"
    }
}
```

When a method receives a legal but undefined *profile name* value for a parameter
with this type, it returns the following error message:

```json
{
    "jsonrpc":"2.0",
    "id":1,
    "error":{
        "message":"Invalid method parameter(s).",
        "data": [
            {
              "path": "/profile",
              "message": "Unknown profile"
            },
        ],
        "code":"-32602"
    }
}
```
The error code is "009" (as above) if method [`job_create`][API job_create]
was requested.
Instead it will be "015" if method [`batch_create`][API batch_create] is requested.


### Progress percentage

Basic data type: number (integer)

An integer ranging from 0 (not started) to 100 (finished).


### Queue

Basic data type: number (integer)

This parameter allows an optional separation of testing in the same database. The default value for the queue is 0. It is closely related to the [`ZONEMASTER.lock_on_queue`][ZONEMASTER.lock_on_queue] parameter of the backend_config.ini file.
The typical use case for this parameter would be a setup with several separate Test Agents running on separate physical or virtual machines each one dedicated to a specific task, for example queue 0 for frontend tests and queue 1 dedicated to batch testing. Running several Test Agents on the same machine is currently not supported.


### Severity level

Basic data type: string

One of the strings (in order from least to most severe):

* `"INFO"`
* `"NOTICE"`
* `"WARNING"`
* `"ERROR"`
* `"CRITICAL"`

Severity levels in Zonemaster are defined in the [Severity Level Definitions]
document. The following severity levels are not available through the RPCAPI
(in order from least to most severe):

* DEBUG3
* DEBUG2
* DEBUG


### Test id

**Deprecated** (planned removal: v2024.1).
Renamed to [*job id*][Job id].


### Test result

**Deprecated** (planned removal: v2024.1).
Renamed to [*job result*][Job result].

### Job id

Basic data type: string

A string of exactly 16 lower-case hex-digits matching `/^[0-9a-f]{16}$/`.

Each *job* (formerly *test*) has a unique *job id* (formerly [*test id*][Test
id]).


### Job result

Basic data type: object

Formerly *test result*.

The object has four keys, `"module"`, `"message"`, `"level"` and `"testcase"`.

* `"module"`: a string. The *test module* that produced the result.
* `"message"`: a string. A human-readable *message* describing that particular result.
* `"level"`: a [*severity level*][Severity level]. The severity of the message.
* `"testcase"`: a string. The *[Test Case Identifier][Test Case Identifiers]* of the *[Test Case][Test Cases]* that produced the result.

Sometimes additional keys are present.

* `"ns"`: a [*domain name*][Domain name]. The name server used by the *test module*.
This key is added when the module name is `"NAMESERVER"`.


### Timestamp

Basic data type: string

A string representing a date and time using the following ISO 8601 format:
"YYYY-MM-DDThh:mm:ssZ".
Example: "2017-12-18T07:56:17Z"

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


## API methods

### API method: `system_versions`

Returns the version of the Zonemaster-LDNS, Zonemaster-Engine and Zonemaster-Backend software combination.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "system_versions"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "zonemaster_ldns": "1.0.1",
    "zonemaster_backend": "1.0.7",
    "zonemaster_engine": "v1.0.14"
  }
}
```


#### `"result"`

An object with the following properties:

* `"zonemaster_ldns"`: A string. The version number of the running *Zonemaster LDNS*.
* `"zonemaster_backend"`: A string. The version number of the running *Zonemaster Backend*.
* `"zonemaster_engine"`: A string. The version number of the *Zonemaster Engine* used by the *RPC API daemon*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


### API method: `conf_profiles`

Returns the names of the public subset of the
[available profiles][Profile sections].

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "conf_profiles"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "profiles": [
      "default",
      "another-profile"
    ]
  }
}
```


#### `"result"`

An oject with the following property:

* `"profiles"`: An array of [*Profile names*][Profile name] in lower case.
  `"default"` is always included.


### API method: `conf_languages`

Returns the set of valid [*language tags*][Language tag].

> Note: If there are two [*locale tags*][LANGUAGE.locale] in [LANGUAGE.locale]
> that would give the same [short language tag][Language tag] then the short tag
> is excluded from the set of valid [*language tags*][Language tag].
>
> Note: Language tags that include country code are *deprecated* (planned
> removal: v2023.1).

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "conf_languages"
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "languages": [
      "da",
      "da_DK",
      "en",
      "en_US",
      "es",
      "es_ES",
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
}
```


#### `"result"`

An oject with the following property:

* `"languages"`: An array of [*language tags*][Language tag]. It is never empty.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for
> clients to know how react to them. Or prevent RPCAPI from starting with
> errors in the configuration file and make it not to reread the configuration
> file while running.
>


### API method: `lookup_address_records`

Looks up the A and AAAA records for a hostname ([*domain name*][Domain name]) on the public Internet.

Example request:

*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "lookup_address_records",
  "params": {"hostname": "zonemaster.net"}
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "address_records": [
      {
        "zonemaster.net": "192.134.4.83"
      },
      {
        "zonemaster.net": "2001:67c:2218:3::1:83"
      }
    ]
  }
}
```


#### `"params"`

An object with the property:

* `"hostname"`: A [*domain name*][Domain name], required. The hostname whose IP addresses are to be resolved.


#### `"result"`

An oject with the following property:

* `"address_record"`: A list of one or two objects representing IP addresses
  (if 2 one is for IPv4 the other for IPv6). The objects each have a single key
  and value. The key is the [*domain name*][Domain name] given as input. The
  value is an IP address for the name, or the value `0.0.0.0` if the lookup
  returned no A or AAAA records.

>
> TODO: If the name resolves to two or more IPv4 address, how is that represented?
>


#### `"error"`

* If any parameter is invalid an error code of -32602 is returned. The `data` property contains an array of all errors, see [Validation error data].

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

### API method: `lookup_delegation_data`

Returns all the NS/IP and DS/DNSKEY/ALGORITHM pairs of the domain from the
parent zone.

Example request:
*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "lookup_delegation_data",
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

* `"domain"`: A [*domain name*][Domain name], required. The domain whose DNS records are requested.
* `"language"`: A [*language tag*][Language tag], optional, used for validation error messages
  translation, if not provided messages will be untranslated (in English).

#### `"result"`

An object with the following properties:

* `"ns_list"`: A list of [*name server*][Name server] objects representing the nameservers of the given [*domain name*][Domain name].
* `"ds_list"`: A list of [*DS info*][DS info] objects representing delegation signer (DS record data) of the given [*domain name*][Domain name].


#### `"error"`

* If any parameter is invalid an error code of -32602 is returned. The `data` property contains an array of all errors, see [Validation error data].

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


### API method: `job_create`

Enqueues a new *job* and returns its [*job_id*][Job id].

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "job_create",
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
  "result": {
    "job_id": "c45a3f8256c4a155"
  }
}
```


#### `"params"`

An object with the following properties:

* `"domain"`: A [*domain name*][Domain name], required. The zone to test.
* `"ipv6"`: A boolean, optional. (default: [`net.ipv4`][net.ipv4] profile value). Used to enable or disable testing over IPv4 transport protocol.
* `"ipv4"`: A boolean, optional. (default: [`net.ipv6`][net.ipv6] profile value). Used to enable or disable testing over IPv6 transport protocol.
* `"nameservers"`: A list of [*name server*][Name server] objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"ds_info"`: A list of [*DS info*][DS info] objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"profile"`: A [*profile name*][profile name], optional. (default:
  `"default"`). Run the tests using the given profile.
* `"client_id"`: A [*client id*][Client id], optional. (default: unset). Used to monitor which client uses the API.
* `"client_version"`: A [*client version*][Client version], optional. (default: unset). Used to monitor which client use the API
* `"priority"`: A [*priority*][Priority], optional. (default: `10`)
* `"queue"`: A [*queue*][Queue], optional. (default: `0`)
* `"language"`: A [*language tag*][Language tag], optional, used for validation error messages
  translation, if not provided messages will be untranslated.


#### `"result"`

An object with the following property:

* `"job_id"`: A [*job id*][Job id].

If a job has been requested with the same parameters (as listed below) not more
than "reuse time" ago, then a new request will not trigger a new job. Instead
the `job_id` of the previous job will be returned. The default value of
"reuse time" is 600 seconds, and can be set by the
[`ZONEMASTER.age_reuse_previous_test`][ZONEMASTER.age_reuse_previous_test] key
in the configuration file.

The parameters that are compared when to determine if two requests are to be
considered to be the same are `domain`, `ipv6`, `ipv4`, `nameservers`, `ds_info`
and `profile`.

#### `"error"`

* If any parameter is invalid an error code of -32602 is returned.
  The `data` property contains an array of all errors, see [Validation error data].

* If the given `profile` is not among the [available profiles][Profile sections],
  a user error is returned, see [profile name section][profile name].

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



### API method: `job_status`

Reports on the progress of a *job*.

Example request:

*Valid syntax:*
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "job_status",
  "params": {
      "job_id": "c45a3f8256c4a155"
  }
}
```

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "progress": 100
  }
}
```


#### `"params"`

An object with the property:

`"test_id"`: **Deprecated** (planned removal v2024.1). A [*test id*][Test id].
The *test* to report on.
`"job_id"`: A [*job id*][Job id], required. The *job* to report on.


#### `"result"`

An object with the following property:

* `"progress"`: A [*progress percentage*][Progress percentage].


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


### API method: `job_results`

Return all [*job result*][Job result] objects of a *job*, with *messages* in the requested language as selected by the
[*language tag*][Language tag].

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "job_results",
  "params": {
    "job_id": "c45a3f8256c4a155",
    "language": "en"
  }
}
```

The `job_id` parameter must match the `job_id` in the response to a
[`job_create`][API job_create] call, and that job must have been completed.

Example response:
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "result": {
    "created_at": "2016-11-15T11:53:13Z",
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
    "testcase_descriptions": {
      "ZONE08": "MX is not an alias",
      "SYNTAX05": "Misuse of '@' character in the SOA RNAME field",
      ...
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

* `"id"`: **Deprecated** (planned removal 2024.1). A [*test id*][Test id].
* `"job_id"`: A [*job id*][Job id], required.
* `"language"`: A [*language tag*][Language tag], required.


#### `"result"`

An object with the following properties:

* `"created_at"`: A [*timestamp*][Timestamp]. The time in UTC at which the *job*
  was created.
* `"hash_id"`: A [*job id*][Job id]. The *job* in question.
* `"params"`: See below.
* `"results"`: A list of [*job result*][Job result] objects.
* `"testcase_descriptions"`: A map with the *[Test Case Identifiers]* as keys and the
  translated *Test Case Description* of the corresponding *[Test Cases]* as values.

If the job was created by [`job_create`][API job_create] then `"params"`
is a normalized version `"params"` object sent to [`job_create`][API job_create]
when the *job* was created.

If the job was created with [`batch_create`][API batch_create] then `"params"`
is a normalized version of an object created from the following parts:
* The keys from the`"job_params"` object sent to [`batch_create`][API batch_create]
  when the *job* was created as part of a batch.
* The `"domain"` key holding the specific [*domain name*][Domain name] for this
  job result from the `"domains"` object included in the call to
  [`batch_create`][API batch_create].

>
> TODO: Change name in the API of `"hash_id"` to `"job_id"`
>


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


### API method: `job_params`

Return a normalized *params* objects of a *job*.

Example request:

*Valid syntax:*
```json
{
    "jsonrpc": "2.0",
    "id": 143014426992009,
    "method": "job_params",
    "params": {
        "job_id": "6814584dc820354a"
    }
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

* `"test_id"`: **Deprecated** (planned removal 2024.1). A [*test id*][Test id].
* `"job_id"`: A [*job id*][Job id], required.


#### `"result"`

The `"params"` object sent to [`job_create`][API job_create] or
[`batch_create`][API batch_create] when the *job* was started.


#### `"error"`

  >
  > TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
  >


### API method: `domain_history`

Returns a list of completed *jobs* for a domain.

Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "domain_history",
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
  "result": {
    "history": [
      {
        "job_id": "c45a3f8256c4a155",
        "created_at": "2016-11-15T11:53:13Z",
        "undelegated": true,
        "overall_result": "error",
      },
      {
        "job_id": "32dd4bc0582b6bf9",
        "undelegated": false,
        "created_at": "2016-11-14T08:46:41Z",
        "overall_result": "error",
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

### Undelegated and delegated

A job is considered to be `"delegated"` below if the job was started, by
[`job_create`][API job_create] or [`batch_create`][API batch_create]
without specifying neither `"nameserver"` nor `"ds_info"`. Else it is considered to
be `"undelegated"`.

#### `"params"`

An object with the following properties:

* `"offset"`: A [*non-negative integer*][Non-negative integer], optional. (default: 0). Position of the first returned element from the database returned list.
* `"limit"`: A [*non-negative integer*][Non-negative integer], optional. (default: 200). Number of element returned from the *offset* element.
* `"filter"`: A string, one of `"all"`, `"delegated"` and `"undelegated"`, optional. (default: `"all"`)
* `"frontend_params"`: An object, required.

The value of "frontend_params" is an object with the following properties:

* `"domain"`: A [*domain name*][Domain name], required.


#### `"result"`

An object with the following properties:

* `"job_id"`: A *job id*.
* `"created_at"`: A [*timestamp*][Timestamp]. The time in UTC at which the *job*
  was created.
* `"overall_result"`: A string. It reflects the most severe problem level among
  the test results for the job. It has one of the following values:
  * `"ok"`, if there are only messages with [*severity level*][Severity level] `"INFO"` or
    `"NOTICE"`.
  * `"warning"`, if there is at least one message with [*severity level*][Severity level]
    `"WARNING"`, but none with `"ERROR"` or `"CRITICAL"`.
  * `"error"`, if there is at least one message with [*severity level*][Severity level]
    `"ERROR"`, but none with `"CRITICAL"`.
  * `"critical"`, if there is at least one message with [*severity level*][Severity level]
    `"CRITICAL"`.
* `"undelegated"`: `true` if the job is undelegated, `false` otherwise.

#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>


### API method: `user_create`

In order to use the [`batch_create`][API batch_create] method a
[*username*][Username] and its [*api key*][Api key] must be added by this method.

This method is not available if [`RPCAPI.enable_user_create`][RPCAPI.enable_user_create]
is disabled (disabled by default). This method is not available unless the connection to
RPCAPI is over localhost (*administrative* method).


Example request:
```json
{
  "jsonrpc": "2.0",
  "method": "user_create",
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
  "result": {
    "success": 1
  }
}
```


#### `"params"`

An object with the following properties:

* `"username"`: A [*username*][Username], required. The [*username*][Username] to be added.
* `"api_key"`: An [*api key*][Api key], required. The [*api key*][Api key] for the [*username*][Username] to be
  added.


#### `"result"`

An object with the following property:

* `"success"`: An integer. The value is equal to 1 if the registration is a
  success, or 0 if it failed.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

Trying to add a already existing user:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "data": {
      "username": "citron"
    },
    "message": "User already exists",
    "code": -32603
  }
}
```

Omitting params:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": "-32602",
    "message": "Invalid method parameter(s).",
    "data": [
      {
        "message": "Expected string - got null.",
        "path": "/api_key"
      }
    ]
  }
}
```

```json
{
  "error": {
    "data": [
      {
        "path": "/username",
        "message": "Expected string - got null."
      }
    ],
    "message": "Invalid method parameter(s).",
    "code": "-32602"
  },
  "jsonrpc": "2.0",
  "id": 1
}
```

Trying to add a user over non-localhost:
```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "error": {
    "code": -32603,
    "data": {
      "remote_ip": "10.0.0.1"
    },
    "message": "Call to \"user_create\" method not permitted from a remote IP"
  }
}
```

Trying to add a user when the method is disabled:
```json
{
  "error": {
    "code": -32601,
    "message": "Procedure 'user_create' not found"
  }
}
```

### API method: `batch_create`

Add a new *batch* composed by a set of [*domain name*][Domain name] and a *job_params* object.
All the domains will be tested using identical parameters.

This method is not available if [`RPCAPI.enable_batch_create`][RPCAPI.enable_batch_create]
is disabled (enabled by default).

A [*username*][Username] and its [*api key*][Api key] can be added with the
[`user_create`][API user_create] method. A [*username*][Username] can only have
one un-finished *batch* at a time.

*Jobs* enqueued using this method are assigned a [*priority*][Priority] of 5.


Example request:
```json
{
  "jsonrpc": "2.0",
  "id": 147559211348450,
  "method": "batch_create",
  "params" : {
    "api_key": "fromage",
    "username": "citron",
    "job_params": {},
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
    "result": {
      "batch_id": 8
    }
}
```


#### `"params"`

An object with the following properties:

* `"username"`: A [*username*][Username], required. The name of the account of an authorized user.
* `"api_key"`: An [*api key*][Api key], required. The api_key associated with the username.
* `"domains"`: A list of [*domain names*][Domain names], required. The domains to be tested.
* `"job_params"`: As described below, optional. (default: `{}`)

The value of `"job_params"` is an object with the following properties:

* `"client_id"`: A [*client id*][Client id], optional. (default: unset)
* `"profile"`: A [*profile name*][profile name], optional (default:
  `"default"`). Run the jobs using the given profile.
* `"client_version"`: A [*client version*][Client version], optional. (default: unset)
* `"nameservers"`: A list of [*name server*][Name server] objects, optional. (default: `[]`)
* `"ds_info"`: A list of [*DS info*][DS info] objects, optional. (default: `[]`)
* `"ipv6"`: A boolean, optional. (default: [`net.ipv4`][net.ipv4] profile value).
* `"ipv4"`: A boolean, optional. (default: [`net.ipv6`][net.ipv6] profile value).
* `"priority"`: A [*priority*][Priority], optional. (default: `5`)
* `"queue"`: A [*queue*][Queue], optional. (default: `0`)


#### `"result"`

An object with the following property:

* `"batch_id"`: An integer. The [*batch id*][Batch id].


#### `"error"`

* You cannot create a new batch job if a *batch* with unfinished *jobs* already
  exists for this [*username*][Username].
* If the given `profile` is not among the [available profiles][Profile sections],
  a user error is returned, see the [profile name section][profile name].

Trying to add a batch when a batch is still running for the [*username*][Username] in the
request:
```json
{
  "jsonrpc": "2.0",
  "error": {
    "data": {
      "created_at": "2021-09-27T07:33:40Z",
      "batch_id": 1
    },
    "code": -32603,
    "message": "Batch job still running"
  },
  "id": 1
}

```

Trying to add a batch when wrong [*username*][Username] or [*api key*][Api key] is used:
```json
{
  "error": {
    "message": "User not authorized to use batch mode",
    "code": -32603,
    "data": {
      "username": "citron"
    }
  },
  "id": 1,
  "jsonrpc": "2.0"
}
```

Trying to add a batch with an empty list of domains:

```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "error": {
    "data": [
      {
        "message": "Not enough items: 0/1.",
        "path": "/domains"
      }
    ],
    "message": "Invalid method parameter(s).",
    "code": "-32602"
  }
}
```

Trying to add a batch when the method has been disabled.
```
{
  "error": {
    "message": "Procedure 'batch_create' not found",
    "code": -32601
  }
}
```


### API method: `batch_status`

Return all [*job id*][Job id] objects of a *batch*, with the number of finished *jobs*.

Example request:

*Valid syntax:*
```json
{
    "jsonrpc": "2.0",
    "id": 147559211994909,
    "method": "batch_status",
    "params": {
        "batch_id": "8"
    }
}
```

Example response:
```json
{
   "jsonrpc": "2.0",
   "id": 147559211994909,
   "result": {
      "nb_finished": 5,
      "finished_job_ids": [
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

* `"batch_id"`: A [*batch id*][Batch id], required.


#### `"result"`

An object with the following properties:

* `"nb_finished"`: a [*non-negative integer*][Non-negative integer]. The number of finished jobs.
* `"nb_running"`: a [*non-negative integer*][Non-negative integer]. The number of running jobs.
* `"finished_job_ids"`: a list of [*job ids*][Job id]. The set of finished *jobs* in this *batch*.


#### `"error"`

If the `batch_id` is undefined the following error is returned:

```json
{
  "id": 1,
  "error": {
    "data": {
      "batch_id": "10"
    },
    "message": "Unknown batch",
    "code": -32603
  },
  "jsonrpc": "2.0"
}
```


## Deprecated

> For details of the deprecated methods' return values see the [version of this
> document][API v10.0.0] included in the v2022.2 release, tagged as "v10.0.0".

### API method: `version_info`

**Deprecated** (planned removal: v2024.1).
Replaced by [`system_versions`][API system_versions].


### API method: `profile_names`

**Deprecated** (planned removal: v2024.1).
Replaced by [`conf_profiles`][API conf_profiles].


### API method: `get_language_tags`

**Deprecated** (planned removal: v2024.1).
Replaced by [`conf_languages`][API conf_languages].

### API method: `get_host_by_name`

**Deprecated** (planned removal: v2024.1).
Replaced by [`lookup_address_records`][API lookup_address_records].


### API method: `get_data_from_parent_zone`

**Deprecated** (planned removal: v2024.1).
Replaced by [`lookup_delegation_data`][API lookup_delegation_data].


### API method: `start_domain_test`

**Deprecated** (planned removal: v2024.1).
Replaced by [`job_create`][API job_create].


### API method: `test_progress`

**Deprecated** (planned removal: v2024.1).
Replaced by [`job_status`][API job_status].


### API method: `get_test_results`

**Deprecated** (planned removal: v2024.1).
Replaced by [`job_results`][API job_results].


### API method: `get_test_history`

**Deprecated** (planned removal: v2024.1).
Replaced by [`domain_history`][API domain_history].


### API method: `add_api_user`

**Deprecated** (planned removal: v2024.1).
Replaced by [`user_create`][API user_create].


### API method: `add_batch_job`

**Deprecated** (planned removal: v2024.1).
Replaced by [`batch_create`][API batch_create].


### API method: `get_batch_job_result`

**Deprecated** (planned removal: v2024.1).
Replaced by [`batch_status`][API batch_status].


### API method: `get_test_params`

**Deprecated** (planned removal: v2024.1).
Replaced by [`job_params`][API job_params].


[API add_api_user]:                   #api-method-add_api_user
[API add_batch_job]:                  #api-method-add_batch_job
[API batch_create]:                   #api-method-batch_create
[API batch_status]:                   #api-method-batch_status
[API conf_languages]:                 #api-method-conf_languages
[API conf_profiles]:                  #api-method-conf_profiles
[API domain_history]:                 #api-method-domain_history
[API job_create]:                     #api-method-job_create
[API job_params]:                     #api-method-job_params
[API job_results]:                    #api-method-job_results
[API job_status]:                     #api-method-job_status
[API key]:                            #api-key
[API lookup_address_records]:         #api-method-lookup_address_records
[API lookup_delegation_data]:         #api-method-lookup_delegation_data
[API start_domain_test]:              #api-method-start_domain_test
[API system_versions]:                #api-method-system_versions
[API user_create]:                    #api-method-user_create
[API v10.0.0]:                        https://github.com/zonemaster/zonemaster-backend/blob/v10.0.0/docs/API.md
[Batch id]:                           #batch-id
[Client id]:                          #client-id
[Client version]:                     #client-version
[Delegation Signer]:                  https://datatracker.ietf.org/doc/html/rfc4034#section-5
[Domain name]:                        #domain-name
[Dot-decimal notation]:               https://en.wikipedia.org/wiki/Dot-decimal_notation
[DS info]:                            #ds-info
[IP address]:                         #ip-address
[ISO 3166-1 alpha-2]:                 https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
[ISO 639-1]:                          https://en.wikipedia.org/wiki/ISO_639-1
[Job id]:                             #job-id
[Job result]:                         #job-result
[JSON Pointer]:                       https://datatracker.ietf.org/doc/html/rfc6901
[JSON-RPC 2.0]:                       https://www.jsonrpc.org/specification
[Language tag]:                       #language-tag
[LANGUAGE.locale]:                    Configuration.md#locale
[Name server]:                        #name-server
[net.ipv4]:                           https://metacpan.org/pod/Zonemaster::Engine::Profile#net.ipv4
[net.ipv6]:                           https://metacpan.org/pod/Zonemaster::Engine::Profile#net.ipv6
[Non-negative integer]:               #non-negative-integer
[Priority]:                           #priority
[Privilege levels]:                   #privilege-levels
[Profile name]:                       #profile-name
[Profile sections]:                   Configuration.md#public-profiles-and-private-profiles-sections
[Progress percentage]:                #progress-percentage
[Queue]:                              #queue
[RFC 5952]:                           https://datatracker.ietf.org/doc/html/rfc5952
[RPCAPI.enable_add_api_user]:         Configuration.md#enable_add_api_user
[RPCAPI.enable_add_batch_job]:        Configuration.md#enable_add_batch_job
[RPCAPI.enable_batch_create]:         Configuration.md#enable_batch_create
[RPCAPI.enable_user_create]:          Configuration.md#enable_user_create
[Severity Level Definitions]:         https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/SeverityLevelDefinitions.md
[Severity level]:                     #severity-level
[Test Cases]:                         https://github.com/zonemaster/zonemaster/tree/master/docs/specifications/tests#list-of-defined-test-cases
[Test Case Identifiers]:              https://github.com/zonemaster/zonemaster/blob/master/docs/internal-documentation/templates/specifications/tests/TestCaseIdentifierSpecification.md
[Test id]:                            #test-id
[Test result]:                        #test-result
[Timestamp]:                          #timestamp
[Username]:                           #username
[Validation error data]:              #validation-error-data
[ZONEMASTER.age_reuse_previous_test]: Configuration.md#age_reuse_previous_test
[ZONEMASTER.lock_on_queue]:           Configuration.md#lock_on_queue

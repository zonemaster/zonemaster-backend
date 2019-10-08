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
* Extra properties in the `"params"` object are allowed for some methods but ignored for others.
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

A positive integer.

The unique id of a *batch*.


### Client id

Basic data type: string

A string of alphanumerics, hyphens, underscores, pluses (`+`), tildes (`~`),
full stops (`.`), colons (`:`) and spaces (` `), of at least 1 and at most 512
characters.
I.e. a string matching `/^[a-zA-Z0-9-+~_.: ]{1,50}$/`.

Represents the name of the client.
Used for monitoring which client (GUI) uses the API.


### Client version

Basic data type: string

A string of alphanumerics, hyphens, pluses, tildes, underscores, full stops,
colons and spaces, of at least 1 and at most 512 characters.
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
* `"digest"`: A string, required. Either 40 or 64 hexadecimal characters (case insensitive).
* `"algorithm"`: An non negative integer, required.
* `"digtype"`: An non negative integer, required.
* `"keytag"`: An non negative integer, required.

Extra properties in *DS info* objects are ignored when present in RPC method arguments, and never returned as part of RPC method results.


### IP address

Basic data type: string

This parameter is a string that are an IPv4 or IPv6. It's validated with the following regexes:
 - IPv4 : `/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/`
 - IPv6 : `/^([0-9A-Fa-f]{1,4}:[0-9A-Fa-f:]{1,}(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?)|([0-9A-Fa-f]{1,4}::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/`


### Name server

Basic data type: object

Properties:

* `"ns"`: A *domain name*, required.
* `"ip"`: An *IP address* (IPv4 or IPv6), optional. (default: unset)


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

When a method received an unknown *profile name* value for in parameter with this type, it returns the following error message:

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
        "message": "Invalid profile option format",
        "status": "nok"
    }
}
```


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

Either:
 * A string of at least 1 and at most 9 digits where the first digit is not a zero, or
 * a string of exactly 16 lower-case hex-digits.

I.e. a string matching `/^([0-9]|[1-9][0-9]{1,8}|[0-9a-f]{16})$/`.

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


### Translation language

Basic data type: string

A string of alphanumeric, hyphens, underscores, full stops and at-signs (`@`),
of at least 1 and at most 30 characters.
I.e. a string matching `/^[a-zA-Z0-9-_.@]{1,30}$/`.

* Any string starting with `"fr"` is interpreted as French.
* Any string starting with `"sv"` is interpreted as Swedish.
* Any string starting with `"da"` is interpreted as Danish.
* Any other string is interpreted as English.


### Unsigned integer

 Basic data type: number (integer)
 
 An unsigned integer is either positive or zero.
 

### Username

Basic data type: string

A string of alphanumerics, dashes, full stops and at-signs, of at least 1 and at
most 50 characters.
I.e. a string matching `/^[a-zA-Z0-9]{1,50}$/`.

Represents the name of an authenticated account (see *[Privilege levels]*)


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

An object with the property:

`"hostname"`: A *domain name*, required. The hostname whose IP addresses are to be resolved.


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

An object with the property:

`"domain"`: A *domain name*, required. The domain whose DNS records are requested.


#### `"result"`

An object with the following properties:

* `"ns_list"`: A list of *name server* objects representing the nameservers of the given *domain name*.
* `"ds_list"`: A list of *DS info* objects representing delegated signer of the given *domain name*.


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
* `"ipv6"`: A boolean, optional. (default `true`). Used to configure the test and enable IPv4 tests.
* `"ipv4"`: A boolean, optional. (default `true`). Used to configure the test and enable IPv6 tests.
* `"nameservers"`: A list of *name server* objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"ds_info"`: A list of *DS info* objects, optional. (default: `[]`). Used to perform un-delegated test.
* `"profile"`: A *profile name*, optional. (default `"default"`). Run the tests using the given profile.
* `"config"`: **Deprecated**. A string, optional. Ignored. Specify `"profile"` instead.
* `"client_id"`: A *client id*, optional. (default: unset). Used to monitor which client uses the API.
* `"client_version"`: A *client version*, optional. (default: unset). Used to monitor which client use the API
* `"priority"`: A *priority*, optional. (default: `10`)
* `"queue"`: A *queue*, optional. (default: `0`)

>
> TODO: Clarify the purpose of each `"params"` property.
>

#### `"result"`

A *test id*. 

If the test has been run with the same domain name within an interval of 10 mins (hard coded), 
then the new request does not trigger a new test, but returns with the results of the last test
 
#### `"error"`

* If the given `profile` is not among the [available profiles], a user
  error is returned.

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
      "profile": "default",
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
* `"language"`: A *translation language*, required.


#### `"result"`

There are two different results depending on the test creation method:

In the case of a test created with `start_domain_test`:

* `"creation_time"`: A *timestamp*. The time at which the *test* was enqueued.
* `"id"`: An integer.
* `"hash_id"`: A *test id*. The *test* in question. 
* `"params"`: The `"params"` object sent to `start_domain_test` when the *test*
  was started.
* `"results"`: A list of *test result* objects.


In the case of a test created with `add_batch_job`:
* `"creation_time"`: A *timestamp*. The time at which the *test* was enqueued.
* `"id"`: An integer.
* `"hash_id"`: A *test id*. The *test* in question. 
* `"params"`: The `"params"` object sent to `start_domain_test` when the *test*
  was started.
* `"results"`: the result is a list of *test id* corresponding to each tested domain.

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

* `"offset"`: An *unsigned integer*, optional. (default: 0). Position of the first returned element from the database returned list.  
* `"limit"`: An *unsigned integer*, optional. (default: 200). Number of element returned from the *offset* element.
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
* `"profile"`: A *profile name*, optional (default `"default"`). Run the tests using the given profile.
* `"config"`: **Deprecated.** A string, optional. Ignored. Specify profile instead.
* `"client_version"`: A *client version*, optional. (default: unset)
* `"nameservers"`: A list of *name server* objects, optional. (default: `[]`)
* `"ds_info"`: A list of *DS info* objects, optional. (default: `[]`)
* `"ipv4"`: A boolean, optional. (default: `true`)
* `"ipv6"`: A boolean, optional. (default: `true`)
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

* `"nb_finished"`: an *unsigned integer*. The number of finished tests.
* `"nb_running"`: an *unsigned integer*. The number of running tests.
* `"finished_test_ids"`: a list of *test ids*. The set of finished *tests* in this *batch*.


#### `"error"`

>
> TODO: List all possible error codes and describe what they mean enough for clients to know how react to them.
>

## API method: `get_test_params`

Return all *params* objects of a *test*.

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

[Available profiles]: Configuration.md#profiles-section
[Privilege levels]: #privilege-levels

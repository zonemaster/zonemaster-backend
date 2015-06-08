# Introduction

This document describes the API of the Zonemaster Backend.

The API is available in the JSON-RPC (version 2.0) format.

Many libraries in about all languages are available to communicate using
the JSON-RPC protocol.

## Backend API

### JSON-RPC Call 1: version\_info
This API returns the version of the Backend+Engine software combination. It is the simplest API to use to check that the backend is running and abswering properly.

**Request**:
```
{
   "params" : "version_info",
   "jsonrpc" : "2.0",
   "id" : 143014362197299,
   "method" : "version_info"
}
```

 -  params: any non empty parameter (empty parameters are not supported as of now)
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
   "jsonrpc" : "2.0",
   "id" : 143014362197299,
   "result" : "Zonemaster Test Engine Version: v1.0.3"
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: the version string

### JSON-RPC Call 2: get\_ns\_ips
This API id used by the NS/IP input forms of the "Undelegated domain test tab". Given a nameserver it returns all of its IP addresses.

**Request**:
```
{
   "params" : "ns1.nic.fr",
   "jsonrpc" : "2.0",
   "id" : 143014382480608,
   "method" : "get_ns_ips"
}
```

 -  params: the name of the server whose IPs need to be resolved
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
   "jsonrpc" : "2.0",
   "id" : 143014382480608,
   "result" : [
      {
         "ns1.nic.fr" : "192.134.4.1"
      },
      {
         "ns1.nic.fr" : "2001:660:3003:2::4:1"
      }
   ]
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: a list of one or two IP addresses (if 2 one is for IPv4 the
    other for IPv6)

### *JSON-RPC Call 3*: get\_data\_from\_parent\_zone
This API returns all the NS/IP and DS/DNSKEY/ALGORITHM pairs of the domain from the parent zone. It is used by the "Fetch data from parent zone" button of the "Undelegated domain test" tab of the web interface.

**Request**:
```
{
   "params" : "nic.fr",
   "jsonrpc" : "2.0",
   "id" : 143014391379310,
   "method" : "get_data_from_parent_zone"
}
```

 -  params: the domain name currently being tested
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
   "jsonrpc" : "2.0",
   "id" : 143014391379310,
   "result" : {
      "ds_list" : [],
      "ns_list" : [
         {
            "ns" : "ns6.ext.nic.fr.",
            "ip" : "130.59.138.49"
         },
         {
            "ns" : "ns6.ext.nic.fr.",
            "ip" : "2001:620:0:1b:5054:ff:fe74:8780"
         },
         {
            "ns" : "ns3.nic.fr.",
            "ip" : "192.134.0.49"
         },
         {
            "ns" : "ns3.nic.fr.",
            "ip" : "2001:660:3006:1::1:1"
         },
         {
            "ns" : "ns2.nic.fr.",
            "ip" : "192.93.0.4"
         },
         {
            "ns" : "ns2.nic.fr.",
            "ip" : "2001:660:3005:1::1:2"
         },
         {
            "ns" : "ns1.ext.nic.fr.",
            "ip" : "193.51.208.13"
         },
         {
            "ns" : "ns4.ext.nic.fr.",
            "ip" : "193.0.9.4"
         },
         {
            "ns" : "ns4.ext.nic.fr.",
            "ip" : "2001:67c:e0::4"
         },
         {
            "ns" : "ns1.nic.fr.",
            "ip" : "192.134.4.1"
         },
         {
            "ns" : "ns1.nic.fr.",
            "ip" : "2001:660:3003:2::4:1"
         }
      ]
   }
}
```

 -   jsonrpc: « 2.0 »
 -   id: any kind of unique id allowing to match requests and responses
 -   result: a list of several { nameserver =\> IP\_adress } pairs.

### *JSON-RPC Call 4*: validate\_syntax
This API checks the "params" structure for syntax coherence. It is very strict on what is allowed and what is not to avoid any SQL injection and cross site scripting attempts. It also checks the domain name for syntax to ensure the domain name seems to be a valid domain name and a test by the Engine can be started.

**Request**:
```
{
   "params" : {
      "domain" : "afnic.fr",
      "ipv6" : 1,
      "ipv4" : 1,
      "nameservers" : [
         {
            "ns" : "ns1.nic.fr",
            "ip" : "1.2.3.4"
         },
         {
            "ns" : "ns2.nic.fr",
            "ip" : "192.134.4.1"
         }
      ]
   },
   "jsonrpc" : "2.0",
   "id" : 143014426992009,
   "method" : "validate_syntax"
}
```
 -  params: the structure representing the frontend parameters structure (see the start_domain_test API for a detailed description)
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
   "jsonrpc" : "2.0",
   "id" : 143014426992009,
   "result" : {
      "status" : "ok",
      "message" : "Syntax ok"
   }
}
```

 -   jsonrpc: « 2.0 »
 -   id : any kind of unique id allowing to match requests and responses
 -   result: either “syntax\_ok” or “syntax\_not\_ok”.

### *JSON-RPC Call 5*: start\_domain\_test
This API inserts a new test request into the database. The test request is inserted with a "progress" (one of the database fields) value of 0 meaning the Engine can start testing this domain.
The testing is done by a (typically) cron job on the backend machine.

**Request**:
```
{
   "jsonrpc" : "2.0",
   "method" : "start_domain_test",
   "params" : {
      "client_id" : "Zonemaster Dancer Frontend",
      "domain" : "afnic.FR",
      "profile" : "default_profile",
      "client_version" : "1.0.1",
      "nameservers" : [
         {
            "ip" : "192.134.4.1",
            "ns" : "ns1.nic.FR."
         },
         {
            "ip" : "2001:660:3003:2:0:0:4:1",
            "ns" : "ns1.nic.FR."
         },
         {
            "ip" : "192.134.0.49",
            "ns" : "ns3.nic.FR."
         },
         {
            "ns" : "ns3.nic.FR.",
            "ip" : "2001:660:3006:1:0:0:1:1",
         },
         {
            "ns" : "ns2.nic.FR.",
            "ip" : "192.93.0.4",
         },
         {
            "ns" : "ns2.nic.FR.",
            "ip" : "2001:660:3005:1:0:0:1:2",
         }
      ],
      "ds_digest_pairs" : [],
      "advanced" : true,
      "ipv6" : true,
      "ipv4" : true
   },
   "id" : 143014514892268
}
```

-   params:
    -   client\_id: "Zonemaster CGI/Dancer/node.js",
        -   \# free string
    -   client\_version: "1.0",
        -   \# free version like string
    -   domain: "afnic.FR",
        -   \# content of the domain text field
    -   advanced: true,
        -   \# true or false, if the advanced options checkbox checked
    -   ipv4: true,
        -   \# true or false, is the ipv4 checkbox checked
    -   ipv6: true,
        -   \# true or false, is the ipv6 checkbox checked
    -   profile: 'default\_profile\_1',
        -   \# the id of the Test profile listbox
    -   nameservers: [
        -   \# list of the namaserves up to 32
            - {
              "ns" : "ns2.nic.FR.",
              "ip" : "192.93.0.4",
            },
            - {
              "ns" : "ns2.nic.FR.",
              "ip" : "2001:660:3005:1:0:0:1:2",
            }
    -   ds\_digest\_pairs: []
        - disabled in the present version

 -   jsonrpc: « 2.0 »
 -   id: any kind of unique id allowing to match requests and responses
 -   method: the name of the called method

**Response**:
```
{
   "id" : 143014514892268,
   "jsonrpc" : "2.0",
   "result" : 8881
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: the id of the test\_result (this id will be used in the
    other APIs related to the same test result).

### *JSON-RPC Call 6*: test\_progress
This API returns the value of the "progress" parameter from the database. Once the progress reaches 100 the test is finished and the results may be retrieved for display.

**Request**:
```
{
   "method" : "test_progress",
   "jsonrpc" : "2.0",
   "id" : 143014514915128,
   "params" : "8881"
}
```

 -  params: the id of the test whose progress indicator has to be
    determined.
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
   "jsonrpc" : "2.0",
   "result" : 0,
   "id" : 143014514915128
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: the % of completion of the test from 0% to 100%

### *JSON-RPC Call 7*: get\_test\_results
This API returns the test result JSON structure from the database. The test results are stored in a language independent format in the database. They are translated into the language given in the "language" parameter and returned to the caller of this API.

**Request**:
```
{
   "id" : 143014516614517,
   "params" : {
      "language" : "en",
      "id" : "8881"
   },
   "jsonrpc" : "2.0",
   "method" : "get_test_results"
}
```

 -  params:
     -  id: the id of the test whose results we want to get.
     -  language: the language of the user interface
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  method: the name of the called method

**Response**:
```
{
  "jsonrpc" : "2.0",
  "id" : 140723510525000,
  "result" : {
    "params" : {
.
.
TEST PARAMS (See *JSON-RPC Call 5*: start_domain_test)
.
.
  },
  "id": 8881,
  "creation_time": "2014-08-05 12:00:13.401442",
  "results": [
    {
      "module": 'DELEGATION',
      "message": 'Messsage for DELEGATION/NAMES_MATCH in the language:fr'
      "level": 'NOTICE',
    },
.
.
LIST OF TEST RESULTS
.
{
  "ns": "ns1.nic.fr",
  "module": "NAMESERVER",
  "message": "Messsage for NAMESERVER/AXFR_FAILURE in the language:fr"
  "level": "NOTICE",
},
.
.
LIST OF TEST RESULTS
.
.
]
}
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: Contains:
     -  id: The id of the test whose results are returnes
     -  creation\_time: The exact time the test was created
     -  params: The parameters used to run this test (See *JSON-RPC Call
        5*: start\_domain\_test)
     -  results: A list of results.

## Description of the results:

The individual results are of the form

```
{
  "module": "DELEGATION",
  "message": "Messsage for DELEGATION/NAMES_MATCH in the language:fr"
  "level": "NOTICE",
}
```

Or

```
{
  "ns": "ns1.nic.fr",
  "module": "NAMESERVER",
  "message": "Messsage for NAMESERVER/AXFR_FAILURE in the language:fr",
  "level": "NOTICE",
}
```

The **module** serves to group the tests by categories.

The **ns** attribute serves to show the name servers for the category
NAMESERVER.

The **message** is the message to show.

The **level** is the level of severity of the message

 -  NOTICE, INFO are considered OK: green
 -  WARNING as warning: orange
 -  ERROR as error: red

### *JSON-RPC Call 8*: get\_test\_history
This API takes the usual fronted "params" structure and uses it to return a list of results for the same domain in the same frontend tab. Currently the presence of the "nameservers" parameter is used to differentiate tests run through the "simple domain test tab" from the "undelegated domain test tab".

**Request**:
```
{
   "jsonrpc" : "2.0",
   "method" : "get_test_history",
   "id" : 143014516615786,
   "params" : {
      "offset" : 0,
      "limit" : 200,
      "frontend_params" : {
         "nameservers" : [
            {
               "ip" : "192.134.4.1",
               "ns" : "ns1.nic.FR."
            },
            {
               "ip" : "2001:660:3003:2:0:0:4:1",
               "ns" : "ns1.nic.FR.",
            },
            {
               "ns" : "ns3.nic.FR.",
               "ip" : "192.134.0.49",
            },
            {
               "ns" : "ns3.nic.FR.",
               "ip" : "2001:660:3006:1:0:0:1:1"
            },
            {
               "ip" : "192.93.0.4",
               "ns" : "ns2.nic.FR.",
            },
            {
               "ns" : "ns2.nic.FR.",
               "ip" : "2001:660:3005:1:0:0:1:2"
            }
         ],
         "ipv4" : true,
         "profile" : "default_profile",
         "ipv6" : true,
         "advanced" : true,
         "domain" : "afnic.FR",
         "ds_digest_pairs" : []
      }
   }
}

```

 -  params: an object containing the following parameters
    -  frontend\_params: the usual structure containing all the
       parameters of the interface
    -  offset: the start of pagination (not yet supported) (optional, default 0)
    -  limit: number of items to return (not yet supported) (optional, default 200)
 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -   method: the name of the called method

**Response**:
```
{
  "jsonrpc": "2.0",
  "id": 140743003648550,
  "result": [
    {
      "advanced_options": "1",
      "id": 3,
      "creation_time": "2014-08-05 19:41:14.522656",
      "overall_result" : "error"
    },
    {
      "advanced_options": "1",
      "id": 1,
      "creation_time": "2014-08-05 11:48:18.542216",
      "overall_result" : "warning"
    }
  ]
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: an ordered (starting by the most recent test) list of tests
    with
    -  id: the id to use to retrieve the test result
    -  creation\_date: the date of test
    -  advanced\_options: if set to 1 serves to differentiate tests
       with advanced options from those without this option.
    - overall\_result: shows if there were any errors or warnings in the result (for color differentiation in the test results history)

## Batch mode API (Experimental as of now)

### *JSON-RPC Call*: create\_user

**Request**:
```
{
  "params": {
    "frontend_params": {
      "test_profile": "test_profile_1",
      "ipv6": 1,
      "ipv4": 1,
      "client_id": "Zonemaster CGI/Dancer/node.js",
      "nameservers": [
        { "ns1.nic.fr": "" },
        { "empty": "192.134.4.1" },
        { "ns1.nic.fr": "192.134.4.1" }
      ],
      "domain": "afnic-2.fr",
      "ds_digest_pairs": [
        { "ds1": "digest1" },
        { "ds2": "digest2" }
      ],
      "advanced_options": 1,
      "client_version": "1.0"
    },
    "limit" : 10,
    "offset" : 0
  },
  "jsonrpc": "2.0",
  "id": 140726285079520,
  "method" : "get_test_history"
}
```

 -  params: an object containing the following parameters
    -  frontend\_params: the usual structure containing all the
       parameters of the interface
    -  offset: the start of pagination
    -  limit: number of items to return
 -   jsonrpc: « 2.0 »
 -   id: any kind of unique id allowing to match requests and responses
 -   method: the name of the called method

**Response**:
```
{
  "jsonrpc": "2.0",
  "id": 140743003648550,
  "result": [
    {
      "advanced_options": "1",
      "id": 3,
      "creation_time": "2014-08-05 19:41:14.522656"
    },
    {
      "advanced_options": "1",
      "id" : 1,
      "creation_time": "2014-08-05 11:48:18.542216"
    }
  ]
}
```

 -  jsonrpc: « 2.0 »
 -  id: any kind of unique id allowing to match requests and responses
 -  result: an ordered (starting by the most recent test) list of tests
    with
    -  id: the id to use to retrieve the test result
    -  creation\_date: the date of test
    -  advanced\_options: if set to 1 serves to differentiate tests
       with advanced options from those without this option.
       

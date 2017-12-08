# Architecture

The Zonemaster *Backend* is a system for performing domain health checks and
keeping records of performed domain health checks.

A Zonemaster *Backend* system consists of at least three components: a
single *Database*, a single *Test Agent* and one or more *RPC API daemons*.


## Components

### Database

The *Database* stores health check requests and results. The *Backend*
architecture is oriented around a single central *Database*.


### Test Agent

A Zonemaster *Test Agent* is a daemon that picks up *test* requests from the
*Database*, runs them using the *Zonemaster Engine* library, and records the results back
to the *Database*. A single *Test Agent* may handle several requests concurrently.
The *Backend* architecture supports a single *Test Agent* daemon interacting with a single *Database*.

>
> TODO: List all files these processes read and write.
>
> TODO: List everything these processes open network connections to.
>
> TODO: Describe in which order *test* are processed.
>
> TODO: Describe how concurrency, parallelism and synchronization works within a single *Test Agent*.
>
> TODO: Describe how synchronization works among parallel *Test Agents*.
>


### Web backend

A Zonemaster *Web backend* is a daemon providing a JSON-RPC interface for
recording *test* requests in the *Database* and fetching *test* results from the
*Database*. The *Backend* architecture supports multiple *RPC API daemons*
interacting with the same *Database*.

This only needs to be run as root in order to make sure the log file
can be opened. The `starman` process will change to the `www-data` user as
soon as it can, and all of the real work will be done as that user.

>
> TODO: List all ports these processes listen to.
>
> TODO: List all files these processes read and write.
>
> TODO: List everything these processes open network connections to.
>


## Glossary

### Test

### Batch

### Test result

### Test module

### Message

### Policy

### Profile

Zonemaster Backend allows users to specify a profile to be used when starting tests.

Zonemaster Backend allows administrators to configure the set of available profiles.

See also: [Profiles overview], [Backend profile configuration]


### Config profile

*Config profiles* are configured under the the `ZONEMASTER` section of `zonemaster_backend.ini`.

>
> TODO: Describe this in greater detail.
>


### Engine

The Zonemaster *Engine* is a library for performing *tests*. It's hosted in [its
own repository](https://github.com/dotse/zonemaster-engine/).

--------
[Backend profile configuration]: Configuration.md#profiles
[Profiles overview]: https://github.com/dotse/zonemaster/blob/master/docs/design/Profiles.md

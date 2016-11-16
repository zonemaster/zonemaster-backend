# Architecture

The Zonemaster *Backend* is a system for performing domain health checks and
keeping records of performed domain health checks.

A Zonemaster *Backend* system consists of at least three components: a
single *Database*, one or more *Workers* and one or more *Web backends*.


## Components

### Database

The *Database* stores health check requests and results. The *Backend*
architecture is oriented around a single central *Database*.


### Worker

A Zonemaster *Worker* is a daemon that picks up *test* requests from the
*Database*, runs them using the *Engine* library, and records the results back
to the *Database*. A single *Worker* may handle several requests concurrently.
The *Backend* architecture supports a single *Workers* interacting with a single
*Database*.

>
> TODO: List all files these processes read and write.
>
> TODO: List everything these processes open network connections to.
>
> TODO: Describe in which order *test* are processed.
>
> TODO: Describe how concurrency, parallelism and synchronization works within a single *Worker*.
>
> TODO: Describe how synchronization works among parallel *Workers*.
>


### Web backend

A Zonemaster *Web backend* is a daemon providing a JSON-RPC interface for
recording *test* requests in the *Database* and fetching *test* results from the
*Database*. The *Backend* architecture supports multiple *Web backends*
interacting with the same *Database*.

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

>
> TODO: Come up with a better name to distinguish it from *config profiles*.
>

### Config profile

*Config profiles* are configured under the the `ZONEMASTER` section of `zonemaster_backend.ini`.

>
> TODO: Describe this in greater detail.
>


### Engine

The Zonemaster *Engine* is a library for performing *tests*. It's hosted in [its
own repository](https://github.com/dotse/zonemaster-engine/).

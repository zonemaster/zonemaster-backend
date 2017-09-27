Zonemaster Backend
==================
[![Build Status](https://travis-ci.org/dotse/zonemaster-backend.svg?branch=master)](https://travis-ci.org/dotse/zonemaster-backend)

### Purpose
This repository is one of the components of the Zonemaster software. For an
overview of the Zonemaster software, please see the
[Zonemaster repository](https://github.com/dotse/zonemaster).

This module is the Backend JSON/RPC weservice for the Web Interface part of
the Zonemaster project. It offers a JSON/RPC api to run tests one by one
(as the zonemaster-gui web frontend module does, or by using a batch API to
run the Zonemaster engine on many domains)

A Zonemaster user needs to install the backend only in the case where there is a
need of logging the Zonemaster test runs in one's own respective database for
analysing.  


### Prerequisites

Before you install the Zonemaster Backend, you need the
Zonemaster Engine installed. Please see the
[Zonemaster Engine installation
instructions](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md).

### Upgrade 

If you are upgrading Zonemaster Backend from 1.0.X to 1.1.X please follow the
[upgrade instructions from 1.0.X to 1.1.X](docs/upgrade-from-1.0.x-to-1.1.x.md) and then follow the
relevant parts of the installation instructions below.

For all other upgrades follow the relevant parts of the installation
instructions below.

### Installation

Follow the detailed [installation instructions](docs/installation.md).

### Configuration 

Zonemaster *Backend* is configured as a whole from `/etc/zonemaster/backend_config.ini`.

>
> At this time there is no documentation for `backend_config.ini`.
>


### Documentation

The Zonemaster Backend documentation is split up into several documents:

* A number of [Typographic Conventions](docs/TypographicConventions.md) are used
  throughout this documentation.
* The [Architecture](docs/Architecture.md) document describes each of the
  Zonemaster Backend components and how they operate. It also discusses all
  central concepts needed to understand the Zonemaster backend, and contains a
  glossary over domain specific technical terms.
* The [Getting Started](docs/GettingStarted.md) guide walks you through creating
  a *test* and following it through its life cycle, all using JSON-RPC calls to
  the *RPC API daemon*.
* The [API](docs/API.md) documentation describes the *RPC API daemon* inteface in
  detail.

The [docs](docs/) directory also contains the SQL commands for manipulating the
database. 


License
=======

The software is released under the 2-clause BSD license. See separate
[LICENSE](LICENSE) file.

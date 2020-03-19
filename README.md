# Zonemaster Backend
[![Build Status](https://travis-ci.org/zonemaster/zonemaster-backend.svg?branch=master)](https://travis-ci.org/zonemaster/zonemaster-backend)


### Purpose
This repository is one of the components of the Zonemaster software. For an
overview of the Zonemaster software, please see the
[Zonemaster repository](https://github.com/zonemaster/zonemaster).

This module is the Backend JSON/RPC weservice for the Web Interface part of
the Zonemaster project. It offers a JSON/RPC api to run tests one by one
(as the zonemaster-gui web frontend module does, or by using a batch API to
run the Zonemaster engine on many domains)

A Zonemaster user needs to install the backend only in the case where there is a
need of logging the Zonemaster test runs in one's own respective database for
analysing.


### Prerequisites

Before you install the Zonemaster Backend, you need the
Zonemaster Engine installed. Please see the
[Zonemaster Engine installation
instructions](https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Installation.md).


### Upgrade 

If you upgrade Zonemaster-Backend and want to keep the content of the database
(MySQL/MariaDB or PostgrSQL) then you should not reset the database when you
follow the installation instructions. In some cases you need to patch the
database when you update Zonemaster-Backend.

Always take a backup if the database is valuable.

Current version                     | Upgrade to version                     | Link to instructions
------------------------------------|----------------------------------------|--------------------------------------
Older than 1.0.3                    | 1.0.3 or newer, but older than 1.1.0   | [upgrade-to-1.0.3]
At least 1.0.3 but older than 1.1.0 | 1.1.0 or newer, but older than 5.0.0   | [upgrade-from-1.0.x-to-1.1.x]
At least 1.1.0 but older than 5.0.0 | 5.0.0 or newer                         | [upgrade-from-4.0.x-to-5.0.x]

To complete the upgrade follow the installation instructions below, except for creating
the database. If you instead want to start from an empty database, then you remove the database
and create a new database using the installations instructions.

### Installation

Follow the detailed [installation instructions](docs/Installation.md).


### Configuration

See the [configuration documentation].


### Documentation

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


## License

The software is released under the 2-clause BSD license. See separate
[LICENSE](LICENSE) file.


[Configuration documentation]: docs/Configuration.md
[upgrade-to-1.0.3]: docs/upgrade-to-1.0.3.md
[upgrade-from-1.0.x-to-1.1.x]: docs/upgrade-from-1.0.x-to-1.1.x.md
[upgrade-from-4.0.x-to-5.0.x]: docs/upgrade-from-4.0.x-to-5.0.x.md

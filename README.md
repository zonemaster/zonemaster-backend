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
follow the [installation instructions]. In some cases you need to patch the
database when you update Zonemaster-Backend.

Always take a backup first if the database is valuable.

Current version                     | Link to instructions  | Comments
------------------------------------|-----------------------|-----------------------
Older than 1.0.3                    | [Upgrade to 1.0.3]    |
At least 1.0.3 but older than 1.1.0 | [Upgrade to 1.1.0]    |
At least 1.1.0 but older than 5.0.0 | [Upgrade to 5.0.0]    |
At least 5.0.0 but older than 5.0.2 | [Upgrade to 5.0.2]    | For MySQL/MariaDB only

If the database was created before Zonemaster-Backend version 5.0.0, then you
have to upgrade in several steps.

To complete the upgrade follow the [installation instructions], except for creating
the database. If you instead want to start from an empty database, then you remove the database
and create a new database using the [installation instructions].

### Installation

Follow the detailed [installation instructions].


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


## License

The software is released under the 2-clause BSD license. See separate
[LICENSE](LICENSE) file.


[Configuration documentation]: docs/Configuration.md
[Installation instructions]:   docs/Installation.md
[Upgrade to 1.0.3]:            docs/upgrade_db_zonemaster_backend_ver_1.0.3.md
[Upgrade to 1.1.0]:            docs/upgrade_db_zonemaster_backend_ver_1.1.0.md
[Upgrade to 5.0.0]:            docs/upgrade_db_zonemaster_backend_ver_5.0.0.md
[Upgrade to 5.0.2]:            docs/upgrade_db_zonemaster_backend_ver_5.0.2.md

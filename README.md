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

See the [upgrade document].


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

This is free software under a 2-clause BSD license. The full text of the license can
be found in the [LICENSE](LICENSE) file included in this respository.


[Configuration documentation]: docs/Configuration.md
[Installation instructions]:   docs/Installation.md
[Upgrade document]:            docs/Upgrade.md

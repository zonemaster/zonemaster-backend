Zonemaster
==========
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

Before you install the Zonemaster CLI utility, you need the
Zonemaster Engine test framework installed. Please see the
[Zonemaster Engine installation
instructions](https://github.com/dotse/zonemaster-engine/blob/master/docs/installation.md)

### Installation

Follow the detailed [installation instructions](docs/installation.md).

### Configuration 

Text for configuring the backend are found in the [installation
instructions](docs/installation.md).

### Documentation

There is a fully documented [API](docs/API.md), which is the primay way
to use the backend. The [docs](docs/) directory also contains the SQL commands
for manipulating the database. 

License
=======

The software is released under the 2-clause BSD license. See separate
[LICENSE](LICENSE) file.



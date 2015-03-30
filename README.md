Zonemaster
==========

Zonemaster is a cooperative project between .SE and AFNIC. It is a successor
to both .SE's DNSCheck and AFNIC's Zonecheck.

This module is the Backend JSON/RPC weservice for the Web Interface part of
the Zonemaster project. It offers a JSON/RPC api to run tests one by one
(as the zonemaster-gui web frontend module does, or by using a batch API to
run the Zonemaster engine on many domains)

Installation
============

Follow the detailed [installation instructions](docs/installation.md).

Prerequisites
=============

The other perl modules required to run the Zonemaster Backend module are
listed in Makefile.PL as usual. 

Documentation
=============

There is a fully documented [API](docs/API.md), which is the primay way
to use the backend.

License
=======

The software is released under the 2-clause BSD license. See separate
[LICENSE](LICENSE) file.


2014-12-05 Michal TOMA, for the Zonemaster development team

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

Follow the detailed
[Doc/zonemaster-backend-installation-instructions.md](installation instructions).

Prerequisites
=============

The other perl modules required to run the Zonemaster Backend module are
listed in Makefile.PL as usual. 

Documentation
=============

A detailed documentation of the API is in the
[ZonemasterBackend.md file](Dov/ZonemasterBackend.md).

License
=======

The software is released under the 2-clause BSD license. See separate LICENSE file.


2014-12-05 Michal TOMA, for the Zonemaster development team

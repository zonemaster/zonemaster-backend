# Configuration

Zonemaster *Backend* is configured as a whole from `/etc/zonemaster/backend_config.ini`
(CentOS, Debian and Ubuntu) or `/usr/local/etc/zonemaster/backend_config.ini`
(FreeBSD).

Each section in `backend_config.ini` is documented below.

## DB section

The DB section has a number of keys.
At this time the only documented key is `engine`.

### engine

Specifies what database engine to use.

The value must be one of the following, case-insensitively: `MySQL`,
`PostgreSQL` and `SQLite`.

This table declares what value to use for each supported database engine.

Database Engine   | Value
------------------|------
MariaDB           | `MySQL`
MySQL             | `MySQL`
PostgreSQL        | `PostgreSQL`
SQLite            | `SQLite`


## GEOLOCATION section

TBD


## LOG section

TBD


## PERL section

TBD


## PUBLIC PROFILES and PRIVATE PROFILES sections

The PUBLIC PROFILES and PRIVATE PROFILES sections together define the available [profiles].

Keys in both sections are [profile names], and values are absolute file system paths to
[profile JSON files]. Keys must not be duplicated between the sections, and the
key `default` must not be present in the PRIVATE PROFILES sections.

There is a `default` profile that is special. It is always available even
if not specified. If it is not explicitly mapped to a profile JSON file, it is implicitly
mapped to the *Zonemaster Engine default profile*.

The *Zonemaster Engine default profile* is created by what is specified in
[Zonemaster::Engine::Profile] and by loading the [Default JSON profile file].

Each profile JSON file contains a (possibly empty) set of overrides to
the *Zonemaster Engine default profile*. Specifying a profile JSON file
that contains a complete set of profile data is equivalent to specifying
a profile JSON file with only the parts that differ from the *Zonemaster
Engine default profile*.

Specifying a profile JSON file that contains no profile data is equivalent
to specifying a profile JSON file containing the entire
*Zonemaster Engine default profile*.

## ZONEMASTER section

TBD

--------

[Zonemaster::Engine::Profile]: https://metacpan.org/pod/Zonemaster::Engine::Profile#PROFILE-PROPERTIES
[Default JSON profile file]: https://github.com/zonemaster/zonemaster-engine/blob/master/share/profile.json
[Profile JSON files]: https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Profiles.md
[Profile names]: API.md#profile-name
[Profiles]: Architecture.md#profile




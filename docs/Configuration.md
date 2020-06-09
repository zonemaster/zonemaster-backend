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

## LANGUAGES

The LANGUAGE section has one key, `lang`.

The value must be a space separated list of locale setting
for the available translation of messages without ".UTF-8"
which is assumed.

Adding a new language to the configuration requires that the
equivalent MO file is added to Zonemaster-Engine at the correct
place so that getext get retreive it. Removing a lanugage from
the configuration file just blocks that language to be displayed.

English is the Zonemaster default language, but can be blocked
from being displayed by RPC-API by not including it in the
configuration.

The default installation and configuration supports the
following languages.

Language | Code in RPC-API* | Value in .ini file | Locale value
---------|------------------|--------------------|-------------
Danish   | da               | da_DK              | da_DK.UTF-8
English  | en               | en_US              | en_US.UTF-8
French   | fr               | fr_FR              | fr_FR.UTF-8
Swedish  | sv               | sv_SE              | sv_SE.UTF-8

*) RPC-API just considers the two first characters of the language
string and disregards the remaining.

The same language code may not be used more than once.

Default setting in the configuration file:

```
lang = da_DK en_US fr_FR sv_SE
```

If the section is empty, "en_US" is set by default.

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




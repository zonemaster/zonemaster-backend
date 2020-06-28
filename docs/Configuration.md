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

## LANGUAGE section

The LANGUAGE section has one key, `lang`.

The value of the `lang` key is a space separated list of
language tags where each tag must match the regular expression
`/^[a-z]{2}_[A-Z]{2}$/`.

The two first characters of a language tag are expected to be an
[ISO 639-1] two-character language code and the two last characters
are expected to be an [ISO 3166-1 alpha-2] two-character country code.
A language tag is a locale setting for the available translation
of messages without ".UTF-8", which is assumed.

Adding a new language to the configuration requires that the
equivalent MO file is added to Zonemaster-Engine at the correct
place so that gettext get retrieve it. Removing a language from
the configuration file just blocks that language from being
allowed.

English is the Zonemaster default language, but can be blocked
from being allowed by RPC-API by not including it in the
configuration.

The default installation and configuration supports the
following languages.

Language | Language tag value | Locale value used
---------|--------------------|------------------
Danish   | da_DK              | da_DK.UTF-8
English  | en_US              | en_US.UTF-8
French   | fr_FR              | fr_FR.UTF-8
Swedish  | sv_SE              | sv_SE.UTF-8

Repeated language tag values are just ignored.

Setting in the default configuration file:

```
lang = da_DK en_US fr_FR sv_SE
```

If the lang key is empty or absent, the language tag value
"en_US" is set by default.

Each locale, including ".UTF-8", set in the configuration file
must also be installed or activate on the system running the RPCAPI
daemon for the translation to work correctly.

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

[Default JSON profile file]:   https://github.com/zonemaster/zonemaster-engine/blob/master/share/profile.json
[ISO 3166-1 alpha-2]:          https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
[ISO 639-1]:                   https://en.wikipedia.org/wiki/ISO_639-1
[Profile JSON files]:          https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Profiles.md
[Profile names]:               API.md#profile-name
[Profiles]:                    Architecture.md#profile
[Zonemaster::Engine::Profile]: https://metacpan.org/pod/Zonemaster::Engine::Profile#PROFILE-PROPERTIES




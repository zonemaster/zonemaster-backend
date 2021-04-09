# Configuration

Zonemaster *Backend* is configured in
`/etc/zonemaster/backend_config.ini` (CentOS, Debian and Ubuntu) or
`/usr/local/etc/zonemaster/backend_config.ini` (FreeBSD). Following
[Installation instructions] will create the file with factory settings.

Each section in `backend_config.ini` is documented below.

Restart the `zm-rpcapi` and `zm-testagent` daemons to load the changes
made to the `backend_config.ini` file.

## DB section

Available keys : `engine`, `user`, `password`, `database_name`,
`database_host`, `polling_interval`.

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

### user

**Deprecated.** Use [MYSQL.user] or [POSTGRESQL.user] instead.

The [MYSQL.user] and [POSTGRESQL.user] properties take precedence over this.

### password

**Deprecated.** Use [MYSQL.password] or [POSTGRESQL.password] instead.

The [MYSQL.password] and [POSTGRESQL.password] properties take precedence over this.

### database_host

**Deprecated.** Use [MYSQL.host] or [POSTGRESQL.host] instead.

The [MYSQL.host] and [POSTGRESQL.host] properties take precedence over this.

### database_name

**Deprecated.** Use [MYSQL.database], [POSTGRESQL.database] or [SQLITE.database_file] instead.

The [MYSQL.database], [POSTGRESQL.database], [SQLITE.database_file] properties take precedence
over this.

### polling_interval

Time in seconds between database lookups by Test Agent.


## MYSQL section

Available keys : `host`, `user`, `password`, `database`.

### host

The host name of the machine on which the MySQL server is running.

If this property is unspecified, the value of [DB.database_host] is used instead.

### user

The name of the user with sufficient permission to access the database.

If this property is unspecified, the value of [DB.user] is used instead.

### password

The password of the configured user.

If this property is unspecified, the value of [DB.password] is used instead.

### database

The name of the database to use.

If this property is unspecified, the value of [DB.database_name] is used instead.


## POSTGRESQL section

Available keys : `host`, `user`, `password`, `database`.

### host

The host name of the machine on which the PostgreSQL server is running.

If this property is unspecified, the value of [DB.database_host] is used instead.

### user

The name of the user with sufficient permission to access the database.

If this property is unspecified, the value of [DB.user] is used instead.

### password

The password of the configured user.

If this property is unspecified, the value of [DB.password] is used instead.

### database

The name of the database to use.

If this property is unspecified, the value of [DB.database_name] is used instead.


## SQLITE section

Available keys : `database_file`.

### database_file

The full path to the SQLite main database file.

If this property is unspecified, the value of [DB.database_name] is used instead.


## LANGUAGE section

The LANGUAGE section has one key, `locale`.

The value of the `locale` key is a space separated list of
`locale tags` where each tag must match the regular expression
`/^[a-z]{2}_[A-Z]{2}$/`.

If the `locale` key is empty or absent, the `locale tag` value
"en_US" is set by default.

The two first characters of a `locale tag` are intended to be an
[ISO 639-1] two-character language code and the two last characters
are intended to be an [ISO 3166-1 alpha-2] two-character country code.
A `locale tag` is a locale setting for the available translation
of messages without ".UTF-8", which is implied.

If a new `locale tag` is added to the configuration then the equivalent
MO file should be added to Zonemaster-Engine at the correct place so
that gettext can retrieve it, or else the added `locale tag` will not
add any actual language support. See the
[Zonemaster-Engine share directory] for the existing PO files that are
converted to MO files. (Here we should have a link
to documentation instead.)

Removing a language from the configuration file just blocks that
language from being allowed. If there are more than one `locale tag`
(with different country codes) for the same language, then
all those must be removed to block that language.

English is the Zonemaster default language, but it can be blocked
from being allowed by RPC-API by not including it in the
configuration.

In the RPCAPI, `language tag` is used ([Language tag]). The
`language tags` are generated from the `locale tags`. Each
`locale tag` will generate two `language tags`, a short tag
equal to the first two letters (usually the same as a language
code) and a long tag which is equal to the full `locale tag`.
If "en_US" is the `locale tag` then "en" and "en_US" are the
`language tags`.

If there are two `locale tags` that would give the same short
`language tag` then that is excluded. E.g. "en_US en_UK" will
only give "en_US" and "en_UK" as `language tags`.

The default installation and configuration supports the
following languages.

Language | Locale tag value   | Locale value used
---------|--------------------|------------------
Danish   | da_DK              | da_DK.UTF-8
English  | en_US              | en_US.UTF-8
French   | fr_FR              | fr_FR.UTF-8
Norwegian| nb_NO              | nb_NO.UTF-8
Swedish  | sv_SE              | sv_SE.UTF-8

The following `language tags` are generated:
* da
* da_DK
* en
* en_US
* fr
* fr_FR
* nb
* nb_NO
* sv
* sv_SE

It is an error to repeat the same `locale tag`.

Setting in the default configuration file:

```
locale = da_DK en_US fr_FR nb_NO sv_SE
```

Each locale set in the configuration file, including the implied
".UTF-8", must also be installed or activate on the system
running the RPCAPI daemon for the translation to work correctly.


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

The ZONEMASTER section has several keys :
* max_zonemaster_execution_time
* number_of_processes_for_frontend_testing
* number_of_processes_for_batch_testing
* lock_on_queue
* maximal_number_of_retries
* age_reuse_previous_test

### max_zonemaster_execution_time

Time in seconds before reporting an unfinished test as failed. Default
value: `600`.

### maximal_number_of_retries

Number of time a test is allowed to be run again if unfinished after
`max_zonemaster_execution_time`. Default value: `0`.

### number_of_processes_for_frontend_testing

used -> todo

### number_of_processes_for_batch_testing

used -> todo

### lock_on_queue

Integer working as a label to associate a test to a specific Test Agent.

### age_reuse_previous_test

Positiv integer (in seconds) for how old a previous test of the same
zone name and parameters must be before we start a new test. Internally
the value is converted to whole minutes. If the conversion results in
zero minutes, then the default value (600 seconds) is used.

--------

[DB.database_host]:                   #database_host
[DB.database_name]:                   #database_name
[DB.password]:                        #password
[DB.user]:                            #user
[Default JSON profile file]:          https://github.com/zonemaster/zonemaster-engine/blob/master/share/profile.json
[ISO 3166-1 alpha-2]:                 https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
[ISO 639-1]:                          https://en.wikipedia.org/wiki/ISO_639-1
[Installation instructions]:          Installation.md
[Language tag]:                       API.md#language-tag
[MYSQL.database]:                     #database
[MYSQL.host]:                         #host
[MYSQL.password]:                     #password-1
[MYSQL.user]:                         #user-1
[POSTGRESQL.database]:                #database-1
[POSTGRESQL.host]:                    #host-1
[POSTGRESQL.password]:                #password-2
[POSTGRESQL.user]:                    #user-2
[Profile JSON files]:                 https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Profiles.md
[Profile names]:                      API.md#profile-name
[Profiles]:                           Architecture.md#profile
[SQLITE.database_file]:               #database_file
[Zonemaster-Engine share directory]:  https://github.com/zonemaster/zonemaster-engine/tree/master/share
[Zonemaster::Engine::Profile]:        https://metacpan.org/pod/Zonemaster::Engine::Profile#PROFILE-PROPERTIES



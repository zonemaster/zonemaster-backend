# Configuration

Zonemaster *Backend* is configured in
`/etc/zonemaster/backend_config.ini` (CentOS, Debian and Ubuntu) or
`/usr/local/etc/zonemaster/backend_config.ini` (FreeBSD). Following
[Installation instructions] will create the file with factory settings.

Restart the `zm-rpcapi` and `zm-testagent` daemons to load the changes
made to the `backend_config.ini` file.

The `backend_config.ini` file uses a file format in the INI family that is
described in detail [here][File format].
Repeating a key name in one section is forbidden.

Each section in `backend_config.ini` is documented below.

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

A strictly positive decimal number. Max 5 and 3 digits in the integer and fraction
components respectively.

Time in seconds between database lookups by Test Agent.
Default value: `0.5`.


## MYSQL section

Available keys : `host`, `port`, `user`, `password`, `database`.

### host

An [LDH domain name] or IP address.

The host name of the machine on which the MySQL server is running.

If this property is unspecified, the value of [DB.database_host] is used instead.

### port

The port the MySQL server is listening on.
Default value: `3306`.

If [MYSQL.host] is set to `localhost` (but neither `127.0.0.1` nor `::1`),
then the value of the [MYSQL.port] property is discarded as the driver
connects using a UNIX socket (see the [DBD::mysql documentation]).

### user

An ASCII-only [MariaDB unquoted identifier].
Max length [80 characters][MariaDB identifier max lengths].

The name of the user with sufficient permission to access the database.

If this property is unspecified, the value of [DB.user] is used instead.

### password

A string of [US ASCII printable characters].
The first character must be neither space nor `<`.
Max length 100 characters.

The password of the configured user.

If this property is unspecified, the value of [DB.password] is used instead.

### database

A US ASCII-only [MariaDB unquoted identifier].
Max length [64 characters][MariaDB identifier max lengths].

The name of the database to use.

If this property is unspecified, the value of [DB.database_name] is used instead.


## POSTGRESQL section

Available keys : `host`, `port`, `user`, `password`, `database`.

### host

An [LDH domain name] or IP address.

The host name of the machine on which the PostgreSQL server is running.

If this property is unspecified, the value of [DB.database_host] is used instead.

### port

The port the PostgreSQL server is listening on.
Default value: `5432`.

### user

A US ASCII-only [PostgreSQL identifier]. Max length 63 characters.

The name of the user with sufficient permission to access the database.

If this property is unspecified, the value of [DB.user] is used instead.

### password

A string of [US ASCII printable characters].
The first character must be neither space nor `<`.
Max length 100 characters.

The password of the configured user.

If this property is unspecified, the value of [DB.password] is used instead.

### database

A US ASCII-only [PostgreSQL identifier]. Max length 63 characters.

The name of the database to use.

If this property is unspecified, the value of [DB.database_name] is used instead.


## SQLITE section

Available keys : `database_file`.

### database_file

An absolute path.

The full path to the SQLite main database file.

If this property is unspecified, the value of [DB.database_name] is used instead.


## LANGUAGE section

The LANGUAGE section has one key, `locale`.

### locale

A string matching one of the following descriptions:
* A space separated list of one or more `locale tags` where each tag matches the
  regular expression `/^[a-z]{2}_[A-Z]{2}$/`.
* The empty string. **Deprecated**, remove the LANGUAGE.locale entry or specify
  LANGUAGE.locale = en_US instead.

It is an error to repeat the same `locale tag`.

If the `locale` key is empty or absent, the `locale tag` value
"en_US" is set by default.

#### Design

The two first characters of a `locale tag` are intended to be an
[ISO 639-1] two-character language code and the two last characters
are intended to be an [ISO 3166-1 alpha-2] two-character country code.
A `locale tag` is a locale setting for the available translation
of messages without ".UTF-8", which is implied.

#### Usage

Removing a language from the configuration file just blocks that
language from being allowed. If there are more than one `locale tag`
(with different country codes) for the same language, then
all those must be removed to block that language.

English is the Zonemaster default language, but it can be blocked
from being allowed by RPC-API by including some `locale tag` in the
configuration, but none starting with language code for English ("en").

The first language in the list will be used as the default for the RPC API
error messages. If translation not available, then the error messages will be
send untranslated, i.e. in English. See the [API documentation] to know which
methods support error message localization.

#### Out-of-the-box support

The default installation and configuration supports the
following languages.

Language | Locale tag value | Language code | Locale value used
---------|------------------|---------------|------------------
Danish   | da_DK            | da            | da_DK.UTF-8
English  | en_US            | en            | en_US.UTF-8
Finnish  | fi_FI            | fi            | fi_FI.UTF-8
French   | fr_FR            | fr            | fr_FR.UTF-8
Norwegian| nb_NO            | nb            | nb_NO.UTF-8
Swedish  | sv_SE            | sv            | sv_SE.UTF-8

Setting in the default configuration file:

```
locale = da_DK en_US fi_FI fr_FR nb_NO sv_SE
```

#### Installation considerations

If a new `locale tag` is added to the configuration then the equivalent
MO file should be added to Zonemaster-Engine at the correct place so
that gettext can retrieve it, or else the added `locale tag` will not
add any actual language support. The MO file should be created for the
`language code` of the `locale tag` (see the table above), not the entire
`locale tag`. E.g. if the `locale` configuration key includes "sv_SE" then
a MO file for "sv" should be included in the installation.

Use of MO files based on the entire `locale tag` is *deprecated*.

See the [Zonemaster-Engine share directory] for the existing PO files that are
converted to MO files during installation. (Here we should have a link
to documentation instead.)

Each locale set in the configuration file, including the implied
".UTF-8", must also be installed or activate on the system
running the RPCAPI daemon for the translation to work correctly.


## PUBLIC PROFILES and PRIVATE PROFILES sections

The PUBLIC PROFILES and PRIVATE PROFILES sections together define the available [profiles].

Keys in both sections are `profile names`, and values are absolute file system
paths to [profile JSON files]. The key must conform to the character limitation
specified for `profile name` as specified in the API document
[Profile name section]. Keys that only differ in case are considered to be equal.
Keys must not be duplicated between or within the sections, and the key
`default` must not be present in the PRIVATE PROFILES section.

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

A strictly positive integer. Max length 5 digits.

Time in seconds before reporting an unfinished test as failed.
Default value: `600`.

### maximal_number_of_retries

A non-negative integer. Max length 5 digits.

Number of time a test is allowed to be run again if unfinished after
`max_zonemaster_execution_time`.
Default value: `0`.

This option is experimental and all edge cases are not fully tested.
Do not use it (keep the default value "0"), or use it with care.

### number_of_processes_for_frontend_testing

A strictly positive integer. Max length 5 digits.

Number of processes allowed to run in parallel (added with
`number_of_processes_for_batch_testing`).
Default value: `20`.

Despite its name, this key does not limit the number of process used by the
frontend, but is used in combination of
`number_of_processes_for_batch_testing`.

### number_of_processes_for_batch_testing

A non-negative integer. Max length 5 digits.

Number of processes allowed to run in parallel (added with
`number_of_processes_for_frontend_testing`).
Default value: `20`.

Despite its name, this key does not limit the number of process used by any
batch pool of tests, but is used in combination of
`number_of_processes_for_frontend_testing`.

### lock_on_queue

A non-negative integer. Max length 5 digits.

A label to associate a test to a specific Test Agent.
Default value: `0`.

### age_reuse_previous_test

A strictly positive integer. Max length 5 digits.

The shelf life of a test in seconds after its creation.
Default value: `600`.

If a new test is requested for the same zone name and parameters within the
shelf life of a previous test result, that test result is reused.
Otherwise a new test request is enqueued.



[DB.database_host]:                   #database_host
[DB.database_name]:                   #database_name
[DB.password]:                        #password
[DB.user]:                            #user
[DBD::mysql documentation]:           https://metacpan.org/pod/DBD::mysql#host
[Default JSON profile file]:          https://github.com/zonemaster/zonemaster-engine/blob/master/share/profile.json
[File format]:                        https://metacpan.org/pod/Config::IniFiles#FILE-FORMAT
[ISO 3166-1 alpha-2]:                 https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
[ISO 639-1]:                          https://en.wikipedia.org/wiki/ISO_639-1
[Installation instructions]:          Installation.md
[Language tag]:                       API.md#language-tag
[LDH domain name]:                    https://datatracker.ietf.org/doc/html/rfc3696#section-2
[MariaDB identifier max lengths]:     https://mariadb.com/kb/en/identifier-names/#maximum-length
[MariaDB unquoted identifier]:        https://mariadb.com/kb/en/identifier-names/#unquoted
[MYSQL.database]:                     #database
[MYSQL.host]:                         #host
[MYSQL.password]:                     #password-1
[MYSQL.user]:                         #user-1
[PostgreSQL identifier]:              https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
[POSTGRESQL.database]:                #database-1
[POSTGRESQL.host]:                    #host-1
[POSTGRESQL.password]:                #password-2
[POSTGRESQL.user]:                    #user-2
[Profile JSON files]:                 https://github.com/zonemaster/zonemaster-engine/blob/master/docs/Profiles.md
[Profile name section]:               API.md#profile-name
[Profiles]:                           Architecture.md#profile
[SQLITE.database_file]:               #database_file
[US ASCII printable characters]:      https://en.wikipedia.org/wiki/ASCII#Printable_characters
[Zonemaster-Engine share directory]:  https://github.com/zonemaster/zonemaster-engine/tree/master/share
[Zonemaster::Engine::Profile]:        https://metacpan.org/pod/Zonemaster::Engine::Profile#PROFILE-PROPERTIES
[API documentation]:                  API.md

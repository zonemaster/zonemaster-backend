# Configuration

Zonemaster Backend is configured as a whole from `/etc/zonemaster/backend_config.ini`.

Each section in `backend_config.ini` is documented below.

## DB section

TBD


## GEOLOCATION section

TBD


## LOG section

TBD


## PERL section

TBD


## PROFILES section

The PROFILES section defines the available [profiles].

Keys are [profile names], and values are absolute file system paths to
[profile JSON files].
Each profile JSON file contains a (possibly empty) set of overrides to
the [Zonemaster Engine default profile].

There is a `default` profile that is special.
It is always available.
If it is not explicitly mapped to a profile JSON file, it is implicitly
mapped to the Zonemaster Engine default profile.

Specifying a profile JSON file that contains a complete set of profile
data is equivalent to specifying a profile JSON file with only the parts
that differ from the Zonemaster Engine default profile.
Specifying a profile JSON file that contains no profile data is equivalent
to specifying a profile JSON file containing the entire Zonemaster Engine
default profile.

## ZONEMASTER section

TBD

--------

[Profile JSON files]: https://metacpan.org/pod/Zonemaster::Engine::Config#PROFILE-DATA
[Profile names]: API.md#profile-name
[Profiles]: Architecture.md#profile
[Zonemaster Engine default profile]: https://metacpan.org/pod/Zonemaster::Engine::Config#DESCRIPTION

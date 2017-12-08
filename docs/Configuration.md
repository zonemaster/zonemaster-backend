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

The PROFILES section declares the available [profiles].

Keys are [profile names], and values are absolute file system paths to [profile JSON files].
The profile named `default` is special and always available.
When it isn't explicitly defined, it's implicitly mapped to the Zonemaster Engine default profile.


## ZONEMASTER section

TBD

--------

[Profile JSON files]: https://metacpan.org/pod/Zonemaster::Engine::Config#PROFILE-DATA
[Profile names]: API.md#profile-name
[Profiles]: Architecture.md#profile

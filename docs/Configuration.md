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

This section declares available [profiles].

Keys are profile names and values are absolute file system paths to profile JSON files.
The profile named `default` is special and always available.
If it isn't explicitly defined, it's implicitly mapped to the Zonemaster Engine default profile.

Legal values for profile names are specified in the [profile name] section of the RPC-API documentation.

The profile file format is specified in the [PROFILE DATA] section of the Zonemaster::Engine::Config.
See the [profile data specification]


## ZONEMASTER section

TBD

--------

[Profile data]: https://metacpan.org/pod/Zonemaster::Engine::Config
[Profile name]: API.md#profile-name
[Profiles]: Architecture.md#profile

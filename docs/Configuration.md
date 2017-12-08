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

Profile names are restricted to:

 * letters A-Z and a-z, digits 0-9, hyphen '-' and underscore '_'
 * minimum one character in length
 * maximum 32 characters in length


## ZONEMASTER section

TBD

--------

[Profiles]: Architecture.md#profile

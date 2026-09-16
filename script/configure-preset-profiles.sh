#!/usr/bin/env bash

# This script:
#   1. Changes its working directory to the directory supplied as its argument.
#   2. Finds all .profile files in Zonemaster-Engine's shared preset profiles
#      directory, using the PROFILE_DIR environment variable to locate it.
#   3. Creates a key=value entry for each profile, using the filename without
#      the ".profile" extension as the key.
#   4. Prompts before changing an already existing profile.
#   5. Updates or adds new profiles to the [PUBLIC PROFILES] section of
#      Zonemaster-Backend's configuration file.

set -e

# Validate arguments and switch to the target (working) directory.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>" >&2
    exit 1
fi
cd "$1"

CONFIG="backend_config.ini"
PROFILE_DIR="${PROFILE_DIR:?PROFILE_DIR must be set}"

# Create temporary files and clean them up on exit.
tmp_profiles="$(mktemp)"
tmp_decisions="$(mktemp)"
tmp_config="$(mktemp)"
trap 'rm -f "$tmp_profiles" "$tmp_decisions" "$tmp_config" "$CONFIG.tmp"' EXIT

# Generate one key=value entry for each profile, using the
# filename without the ".profile" extension as the key.
for f in "$PROFILE_DIR"/*.profile; do
    [ -f "$f" ] || continue
    b=${f##*/}
    printf '%s=%s\n' "${b%.profile}" "$f"
done > "$tmp_profiles"

# Ask before replacing an existing profile whose path has changed.
while IFS='=' read -r key path; do
    [ -n "$key" ] || continue

    existing="$(awk -v key="$key" '
        /^\[PUBLIC PROFILES\]$/ { in_profiles=1; next }
        /^\[/ { in_profiles=0 }
        in_profiles && index($0, key "=") == 1 {
            print substr($0, length(key) + 2)
            exit
        }
    ' "$CONFIG")"

    if [ -n "$existing" ]; then
        if [ "$existing" != "$path" ]; then
            printf "Profile '%s' already exists:\n  %s\nReplace with:\n  %s\n? [y/n] " \
                "$key" "$existing" "$path"
            read -r answer < /dev/tty

            case "$answer" in
                y|Y|yes|YES)
                    printf '%s=y\n' "$key" >> "$tmp_decisions"
                    ;;
                *)
                    printf '%s=n\n' "$key" >> "$tmp_decisions"
                    ;;
            esac
        else
            # The profile already points to the correct path.
            printf '%s=same\n' "$key" >> "$tmp_decisions"
        fi
    else
        # New profile
        printf '%s=new\n' "$key" >> "$tmp_decisions"
    fi
done < "$tmp_profiles"

# Update existing profiles (if necessary and according to the user's decisions)
# and add new ones;
awk -v profiles="$tmp_profiles" -v decisions="$tmp_decisions" '
BEGIN {
    while ((getline line < profiles) > 0) {
        sep = index(line, "=")
        key = substr(line, 1, sep - 1)
        newentry[key] = line
    }
    close(profiles)

    while ((getline line < decisions) > 0) {
        sep = index(line, "=")
        key = substr(line, 1, sep - 1)
        decision[key] = substr(line, sep + 1)
    }
    close(decisions)
}

/^\[PUBLIC PROFILES\]$/ {
    print
    in_profiles = 1
    next
}

/^\[/ {
    if (in_profiles) {
        for (key in newentry)
            if (!found[key] && decision[key] == "new")
                print newentry[key]
        in_profiles = 0
    }
    print
    next
}

in_profiles && /^[^=]+=/ {
    sep = index($0, "=")
    key = substr($0, 1, sep - 1)

    if (key in newentry) {
        if (decision[key] == "y")
            print newentry[key]
        else
            print
        found[key] = 1
    } else {
        print
    }
    next
}

{ print }

END {
    if (in_profiles)
        for (key in newentry)
            if (!found[key] && decision[key] == "new")
                print newentry[key]
}
' "$CONFIG" > "$tmp_config"

# Replace the configuration file while preserving its existing permissions and ownership.
install -p "$CONFIG" "$CONFIG.tmp"
cat "$tmp_config" > "$CONFIG.tmp"
mv "$CONFIG.tmp" "$CONFIG"

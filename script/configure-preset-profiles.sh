#!/bin/sh

# This script:
#   1. Changes its working directory to the directory supplied as its argument.
#   2. Finds all .json and .yaml files in Zonemaster-Engine's shared preset
#      profiles directory, using the PROFILE_DIR environment variable to
#      locate it.
#   3. Creates a key=value entry for each profile, using the filename without
#      the ".json" or ".yaml" extension as the key.
#   4. Updates or adds new profiles to the [PUBLIC PROFILES] section of
#      Zonemaster-Backend's configuration file.
#      User confirmation is required before replacing the configuration file.

set -e

# Help function to ask a yes/no question on the terminal. Returns 0 for yes,
# 1 for no and 2 if no answer could be read.
ask() {
    printf '%s [y/n] ' "$1"
    if ! read -r answer < /dev/tty; then
        echo
        return 2
    fi
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate arguments and switch to the target (working) directory.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>" >&2
    exit 1
fi

PROFILE_DIR="${PROFILE_DIR:?PROFILE_DIR must be set}"
if [ ! -d "$PROFILE_DIR" ]; then
    echo "$0: PROFILE_DIR: $PROFILE_DIR: not a directory" >&2
    exit 1
fi
PROFILE_DIR="$(cd "$PROFILE_DIR" && pwd)"

cd "$1"

CONFIG="backend_config.ini"
NEW_CONFIG="$CONFIG.new"

if [ ! -f "$CONFIG" ]; then
    echo "$0: $(pwd)/$CONFIG: no such file" >&2
    exit 1
fi

# Check for an already existing proposed configuration file. Ask
# confirmation before proceeding.
if [ -e "$NEW_CONFIG" ]; then
    echo "A proposed configuration from a previous run already exists:"
    echo "  $(pwd)/$NEW_CONFIG"
    status=0
    ask "Overwrite it?" 2>/dev/null || status=$?
    if [ "$status" -ne 0 ]; then
        echo "Aborting. Review, apply or remove that file, then run this script again." >&2
        exit 1
    fi
fi

# Create a temporary file and clean it up on exit. The new configuration
# file is also removed, unless the user chose to keep it.
keep_new=0
tmp_profiles="$(mktemp)"
trap 'rm -f "$tmp_profiles"; [ "$keep_new" = 1 ] || rm -f "$NEW_CONFIG"' EXIT
trap 'exit 1' HUP INT TERM

# Generate one key=value entry for each profile, using the filename without
# the ".json" or ".yaml" extension as the key. Warns if both exist, as the key
# would be ambiguous, and only keeps the .json file.
for f in "$PROFILE_DIR"/*.json "$PROFILE_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    b=${f##*/}
    key=${b%.*}
    if cut -d= -f1 "$tmp_profiles" | grep -Fqx -- "$key"; then
        printf "\nIgnoring '%s': profile '%s' already defined by another file (.json)\n" \
            "$f" "$key" >&2
        continue
    fi
    printf '%s=%s\n' "$key" "$f" >> "$tmp_profiles"
done

if [ ! -s "$tmp_profiles" ]; then
    echo "$0: no .json or .yaml profiles found in $PROFILE_DIR" >&2
    exit 1
fi

# Copy the configuration file first so that the new file gets the same
# permissions.
cp -p "$CONFIG" "$NEW_CONFIG"

# Update existing profiles and add new ones.
sort -o "$tmp_profiles" "$tmp_profiles"
awk -v profiles="$tmp_profiles" '
BEGIN {
    n = 0
    while ((getline line < profiles) > 0) {
        sep = index(line, "=")
        key = substr(line, 1, sep - 1)
        newpath[key] = substr(line, sep + 1)
        newentry[key] = key " = " newpath[key]
        order[++n] = key
    }
    close(profiles)
}

# Print the profiles not already present in the section, with the same
# line ending as the configuration file.
function add_new(    i) {
    for (i = 1; i <= n; i++)
        if (!found[order[i]])
            print newentry[order[i]] eol
}

# Detect CRLF line endings (from the first line).
NR == 1 && /\r$/ { eol = "\r" }

# Print the blank lines held back while inside the section.
function flush_blanks() {
    printf "%s", blanks
    blanks = ""
}

# Section headers, allowing surrounding whitespace and CRLF line endings.
/^[ \t]*\[PUBLIC PROFILES\][ \t\r]*$/ {
    print
    in_profiles = 1
    seen_section = 1
    next
}

/^[ \t]*\[/ {
    if (in_profiles) {
        add_new()
        flush_blanks()
        in_profiles = 0
    }
    print
    next
}

in_profiles && /^[ \t\r]*$/ {
    blanks = blanks $0 "\n"
    next
}

# Entries may have whitespace around the key and the value ("key = value").
# Matching ignores it; an updated entry keeps the original layout (and line
# endings) and only has its value replaced.
in_profiles {
    flush_blanks()
    sep = index($0, "=")
    key = sep ? substr($0, 1, sep - 1) : ""
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    if (sep && (key in newentry)) {
        found[key] = 1
        line = $0
        cr = sub(/\r$/, "", line) ? "\r" : ""
        match(line, /^[^=]*=[ \t]*/)
        print substr(line, 1, RLENGTH) newpath[key] cr
    } else {
        print
    }
    next
}

{ print }

END {
    if (in_profiles) {
        add_new()
        flush_blanks()
    } else if (!seen_section && n > 0) {
        print eol
        print "[PUBLIC PROFILES]" eol
        add_new()
    }
}
' "$CONFIG" > "$NEW_CONFIG"

echo
if diff -u "$CONFIG" "$NEW_CONFIG"; then
    echo "No changes to $(pwd)/$CONFIG."
    exit 0
fi
echo

# Show the changes and ask for confirmation before applying them.
status=0
ask "Replace $(pwd)/$CONFIG with the changes above?" 2>/dev/null || status=$?
if [ "$status" -eq 0 ]; then
    mv "$NEW_CONFIG" "$CONFIG"
    echo "Updated $(pwd)/$CONFIG."
    exit 0
fi

# Changes not applied. Ask to keep the proposed configuration for manual review.
echo "Configuration file left unchanged."
if [ "$status" -eq 1 ]; then
    status=0
    ask "Keep the proposed configuration for manual review?" 2>/dev/null || status=$?
fi

if [ "$status" -ne 1 ]; then
    keep_new=1
    echo "Proposed configuration written to:"
    echo "  $(pwd)/$NEW_CONFIG"
else
    echo "Proposed configuration discarded."
fi

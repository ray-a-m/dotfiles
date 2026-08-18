#!/usr/bin/env bash
# Symlink dotfiles librewolf/user.js into every LibreWolf profile.
#
# Why a script and not a fixed path in install.sh: LibreWolf gives each profile
# directory a random prefix, for example "FJFUT5hC.Profile 1". The name differs
# on each machine. This script reads profiles.ini and links into each profile
# that it finds.
#
# LibreWolf reads user.js at start and copies the values into prefs.js. The
# browser never writes to user.js. A link is therefore safe, and an edit in the
# dotfiles repo reaches the browser at the next restart.
set -e

PROFILE_ROOT="${HOME}/.config/librewolf/librewolf"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/user.js"

if [ ! -d "$PROFILE_ROOT" ]; then
    echo "librewolf link-user-js: $PROFILE_ROOT missing (never started?); skipping"
    exit 0
fi

found=0
while IFS= read -r rel; do
    dir="$PROFILE_ROOT/$rel"
    [ -d "$dir" ] || continue
    ln -sfn "$SRC" "$dir/user.js"
    echo "librewolf link-user-js: linked $dir/user.js"
    found=$((found + 1))
done < <(sed -n 's/^Path=//p' "$PROFILE_ROOT/profiles.ini" 2>/dev/null)

if [ "$found" -eq 0 ]; then
    echo "librewolf link-user-js: no profiles found in profiles.ini; skipping"
fi

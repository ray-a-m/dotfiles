#!/usr/bin/env bash
# Symlink dotfiles firefox/user.js into every Firefox profile.
#
# Why a script and not a fixed path in install.sh: Firefox gives each profile
# directory a random prefix, for example "FJFUT5hC.Profile 1". The name
# differs on each machine. This script reads profiles.ini and links into each
# profile that it finds.
#
# Firefox keeps its profiles under ~/.mozilla/firefox when that directory
# holds a profiles.ini, else under $XDG_CONFIG_HOME/mozilla/firefox (this
# machine). The first root with a profiles.ini wins.
#
# Firefox reads user.js at start and copies the values into prefs.js. The
# browser never writes to user.js. A link is therefore safe, and an edit in
# the dotfiles repo reaches the browser at the next restart.
set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/user.js"
PROFILE_ROOT=""
for root in "${HOME}/.mozilla/firefox" "${XDG_CONFIG_HOME:-${HOME}/.config}/mozilla/firefox"; do
    if [ -f "$root/profiles.ini" ]; then
        PROFILE_ROOT="$root"
        break
    fi
done

if [ -z "$PROFILE_ROOT" ]; then
    echo "firefox link-user-js: no profiles.ini under ~/.mozilla/firefox or ~/.config/mozilla/firefox (never started?); skipping"
    exit 0
fi

found=0
while IFS= read -r rel; do
    dir="$PROFILE_ROOT/$rel"
    [ -d "$dir" ] || continue
    ln -sfn "$SRC" "$dir/user.js"
    echo "firefox link-user-js: linked $dir/user.js"
    found=$((found + 1))
done < <(sed -n 's/^Path=//p' "$PROFILE_ROOT/profiles.ini" 2>/dev/null)

if [ "$found" -eq 0 ]; then
    echo "firefox link-user-js: no profiles found in profiles.ini; skipping"
fi

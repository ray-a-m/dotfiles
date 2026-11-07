#!/usr/bin/env bash
# Fold dotfiles firefox/policies-overlay.json into Firefox's policy file,
# /usr/lib/firefox/distribution/policies.json, in place.
#
# Why: Firefox reads one policy file and does not merge several. Omarchy
# writes this one when it installs Firefox (its own preferences: VA-API,
# fractional scaling, no default-browser check), and the Arch package does
# not own the path, so an upgrade leaves it alone. The overlay adds the
# Bitwarden extension. jq's `*` is a deep merge: overlay keys win on
# conflict, and nested objects (ExtensionSettings) merge child by child, so
# a second run changes nothing and says so.
set -e

TARGET=/usr/lib/firefox/distribution/policies.json
OVERLAY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/policies-overlay.json"

if [ ! -f "$TARGET" ]; then
    echo "firefox merge-policies: $TARGET missing (Firefox not installed the Omarchy way?); skipping"
    exit 0
fi

merged="$(jq -S -s '.[0] * .[1]' "$TARGET" "$OVERLAY")"
if [ "$merged" = "$(jq -S . "$TARGET")" ]; then
    echo "firefox merge-policies: $TARGET already carries the overlay"
    exit 0
fi
printf '%s\n' "$merged" | sudo tee "$TARGET" >/dev/null
echo "firefox merge-policies: wrote $TARGET"

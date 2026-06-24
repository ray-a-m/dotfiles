#!/usr/bin/env bash
# Merge dotfiles librewolf/policies-overlay.json onto the LibreWolf package's
# shipped /usr/lib/librewolf/distribution/policies.json and write the union to
# /etc/librewolf/policies/policies.json.
#
# Why: LibreWolf ships policy defaults (uBlock auto-install, search engine
# blocks, telemetry kill) inside the package. Mozilla's policy loader prefers
# /etc/librewolf/policies/policies.json and REPLACES (does not merge with) the
# package file. So if we want to add our own extensions (Bitwarden) without
# losing LibreWolf's hardening, we have to do the merge ourselves and emit it
# into /etc/.
#
# Re-run after every librewolf-bin upgrade (via pacman hook) because the
# package may have added new default policies we want to preserve.
set -e

BASE=/usr/lib/librewolf/distribution/policies.json
OVERLAY=/home/raymond/code/dotfiles/librewolf/policies-overlay.json
OUT=/etc/librewolf/policies/policies.json

if [ ! -f "$BASE" ]; then
    echo "librewolf merge-policies: $BASE missing (librewolf-bin not installed?); skipping"
    exit 0
fi
if [ ! -f "$OVERLAY" ]; then
    echo "librewolf merge-policies: $OVERLAY missing; skipping"
    exit 0
fi

# jq's `*` operator does a deep/recursive object merge: overlay keys win on
# conflict, nested objects (like ExtensionSettings) have their children merged
# rather than the whole subtree replaced. So our Bitwarden entry slots in
# alongside LibreWolf's uBlock0 + search-engine blocks.
sudo mkdir -p "$(dirname "$OUT")"
jq -s '.[0] * .[1]' "$BASE" "$OVERLAY" | sudo tee "$OUT" >/dev/null
echo "librewolf merge-policies: wrote $OUT"

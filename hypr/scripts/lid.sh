#!/usr/bin/env bash
# Lid-close handler. With an external attached, disable the internal panel; with
# none, suspend. internal_off_atomic goes straight from mirror to disabled in one
# reload (NOT mirror_off then monitor-internal off) — the two-step version raced
# mpvpaper and blanked the external's wallpaper. See mirror-helper.sh.
# Requires logind to ignore lid events (see /etc/systemd/logind.conf.d/).

source "$(dirname "$0")/mirror-helper.sh"

# external_present_stable (not the raw check) so a transient DRM disconnect at
# the moment of lid-close doesn't suspend a docked machine — see mirror-helper.sh.
if external_present_stable; then
    internal_off_atomic
else
    systemctl suspend
fi

#!/usr/bin/env bash
# Lid-open handler. The stock lid binds are replaced wholesale in local.lua,
# so re-enabling the internal panel is on us too, not just the mirroring:
# - external present: mirror_on clears the clamshell flag and applies the
#   mirror rule in one reload (the rule itself re-enables the panel).
# - no external: defer to omarchy-hyprland-monitor-clamshell, whose enable
#   path clears a stale clamshell flag, restores the configured scale, and
#   wakes the panel (dpms). Near no-op when no flag exists.

source "$(dirname "$0")/mirror-helper.sh"

if omarchy-hw-external-monitors; then
    mirror_on
else
    omarchy-hyprland-monitor-clamshell
fi

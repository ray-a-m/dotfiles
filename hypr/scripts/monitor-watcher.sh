#!/usr/bin/env bash
# Re-evaluate dock policy on monitor hot-plug, plus an initial-state check at
# start. Bindl on Lid Switch can't catch the case where the lid is ALREADY
# closed and an external is then connected (or disconnected) — the lid state
# never changes, so no event fires. This watcher subscribes to Hyprland's IPC
# and applies policy on every monitor add/remove.
#
# Policy:
#   lid open + external    → mirror external onto internal
#   lid closed + external  → external standalone (drop mirror, disable internal)
#   lid closed + no ext    → suspend
#   lid open + no ext      → nothing to do (defaults are correct)

set -u

LID_FILE="/proc/acpi/button/lid/LID/state"

reevaluate() {
    if grep -q closed "$LID_FILE"; then
        if omarchy-hw-external-monitors; then
            omarchy-hyprland-monitor-internal-mirror off
            omarchy-hyprland-monitor-internal off
        else
            systemctl suspend
        fi
    else
        if omarchy-hw-external-monitors; then
            omarchy-hyprland-monitor-internal-mirror on
        fi
    fi
}

reevaluate

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
[ -S "$sock" ] || exit 1

socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*) reevaluate ;;
    esac
done

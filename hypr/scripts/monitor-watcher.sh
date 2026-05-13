#!/usr/bin/env bash
# Re-evaluate dock policy on monitor hot-plug, plus an initial-state check at
# start. Bindl on Lid Switch can't catch the case where the lid is ALREADY
# closed and an external is then connected (or disconnected) — the lid state
# never changes, so no event fires. This watcher subscribes to Hyprland's IPC
# and applies policy on every monitor add/remove.
#
# Policy:
#   lid open + external    → laptop mirrors external (so external renders at
#                            its native resolution; laptop downscales)
#   lid closed + external  → external standalone (drop mirror, disable internal)
#   lid closed + no ext    → suspend
#   lid open + no ext      → nothing to do (defaults are correct)
#
# Run under systemd user manager (Restart=always) — see
# ../../systemd/user/monitor-watcher.service. stdout/stderr go to the journal:
#   journalctl --user -u monitor-watcher.service

set -u

source "$(dirname "$0")/mirror-helper.sh"

LID_FILE="/proc/acpi/button/lid/LID/state"

log() { printf '[monitor-watcher] %s\n' "$*" >&2; }

reevaluate() {
    if grep -q closed "$LID_FILE"; then
        if omarchy-hw-external-monitors; then
            log "lid closed + external → external standalone"
            mirror_off
            omarchy-hyprland-monitor-internal off
        else
            log "lid closed + no external → suspending"
            systemctl suspend
        fi
    else
        if omarchy-hw-external-monitors; then
            log "lid open + external → mirror on"
            mirror_on
        fi
    fi
}

# Wait for Hyprland socket. Under systemd user manager the service may be
# (re)started before HYPRLAND_INSTANCE_SIGNATURE is exported into the user
# environment, or before the socket itself exists. Poll for up to 30s.
sock=""
for _ in $(seq 1 60); do
    sig="${HYPRLAND_INSTANCE_SIGNATURE:-$(systemctl --user show-environment 2>/dev/null | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')}"
    if [ -n "$sig" ]; then
        candidate="$XDG_RUNTIME_DIR/hypr/$sig/.socket2.sock"
        if [ -S "$candidate" ]; then
            sock="$candidate"
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            break
        fi
    fi
    sleep 0.5
done

if [ -z "$sock" ]; then
    log "timed out waiting for Hyprland socket; exiting"
    exit 1
fi

log "socket ready at $sock; applying initial policy"
reevaluate

socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*) reevaluate ;;
    esac
done

log "socat exited; service will restart"

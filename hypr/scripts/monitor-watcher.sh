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

# Cooldown timestamps for the heals below (epoch seconds; 0 = never). A lid/dock
# transition fires a BURST of monitor events; without a cooldown each one would
# re-restart quickshell / re-fire the wallpaper hook before the fresh instance
# can map its surface, so nothing ever comes back (the "monitor went dark" on a
# lid-close, 2026-07-10). These persist across iterations of the socat while-loop.
_last_qs_restart=0
_last_wp_refire=0

log() { printf '[monitor-watcher] %s\n' "$*" >&2; }

# The wallpaper can vanish during a dock transition — mpvpaper either crashes
# (SIGABRT in libavcodec/libmpv on wl_output churn, observed 2026-06-10) or
# survives as a process while losing its output binding. Heal by re-firing the
# theme-set hook whenever no wallpaper LAYER is present (see the check below).
# This is only the fast path: crashes landing after the 1s check (seen
# 2026-06-23) and login races with no monitor event are caught by
# wallpaper-watchdog.timer within ~30s.
heal_wallpaper() {
    sleep 1  # let output topology settle
    # Check for an actual wallpaper LAYER, not just a live process. mpvpaper
    # (and swaybg) can survive a dock/lid transition as a running process while
    # losing its output binding — pgrep still finds it, but the screen is black.
    # The old both-dead pgrep check skipped exactly that case, which is what
    # left the external dark on lid-close (2026-07-10).
    # namespace = mpvpaper|swaybg (pre-Quattro) or omarchy-background (the
    # Quattro shell's own image layer). A video theme whose mpvpaper died
    # while the shell's static fallback survived slips past this fast path;
    # wallpaper-watchdog.timer restores the video within ~30s and the
    # fallback art keeps the screen from going black meanwhile.
    hyprctl layers 2>/dev/null | grep -qE 'namespace: (mpvpaper|swaybg|omarchy-background)' && return
    local now; now=$(date +%s)
    (( now - _last_wp_refire < 8 )) && return
    _last_wp_refire=$now
    log "no wallpaper layer post-event; re-firing theme-set hook"
    "$HOME/.config/omarchy/hooks/theme-set"
}

# Quickshell sometimes survives a dock transition as a process but loses
# its layer surfaces — pills disappear even though the process is alive
# (observed 2026-06-10: bar pills gone after docked→undocked, fixed by
# restart). Check for any quickshell-* layer surface; if none, restart.
# Normal events where the surfaces survive are no-ops.
heal_quickshell() {
    hyprctl layers 2>/dev/null | grep -q 'namespace: quickshell-' && return
    # quickshell loses its layer surfaces when its output is reconfigured during
    # a dock/lid transition and does NOT re-anchor on its own — it needs a
    # restart to repaint. Do it promptly (a grace window just prolongs the dark
    # screen), but debounce with a cooldown: the transition fires a burst of
    # monitor events, and restarting on each one (4x in 5s observed 2026-07-10)
    # kills quickshell before it can map its surfaces, so it never comes back.
    # One restart per window; a fresh instance gets the whole window to come up.
    local now; now=$(date +%s)
    (( now - _last_qs_restart < 8 )) && return
    _last_qs_restart=$now
    log "quickshell has no layer surfaces post-event; restarting"
    pkill -x quickshell 2>/dev/null
    for _ in $(seq 1 20); do
        pgrep -x quickshell >/dev/null || break
        sleep 0.1
    done
    setsid uwsm-app -- quickshell -d -n >/dev/null 2>&1 &
    disown
}

reevaluate() {
    if grep -q closed "$LID_FILE"; then
        # external_present_stable (debounced) so a transient DRM disconnect
        # during dock-transition churn doesn't suspend a docked machine — the
        # burst of monitoradded/removed events fires reevaluate() repeatedly,
        # and a single flake used to loop us through suspend. See mirror-helper.sh.
        if external_present_stable; then
            log "lid closed + external → external standalone"
            internal_off_atomic
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
        monitoradded*|monitorremoved*) reevaluate; heal_wallpaper; heal_quickshell ;;
    esac
done

log "socat exited; service will restart"

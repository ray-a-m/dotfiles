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
# True when the active theme carries a video background — pre-Quattro via the
# current/background symlink, Quattro via the theme's backgrounds dirs. Same
# detection as wallpaper-watchdog.sh.
video_expected() {
    local legacy ext theme
    legacy=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null)
    if [ -n "$legacy" ] && [ -e "$legacy" ]; then
        ext="${legacy##*.}"
        case "${ext,,}" in
            mp4|webm|mkv|mov|avi) return 0 ;;
            *) return 1 ;;
        esac
    fi
    theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
    [ -n "$theme" ] || return 1
    [ -n "$(find -L "$HOME/.config/omarchy/backgrounds/$theme/" \
        "$HOME/.local/state/omarchy/current/theme/backgrounds/" -maxdepth 1 -type f \
        \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \) \
        2>/dev/null | head -n1)" ]
}

# Video health = mpvpaper's layer mapped and, on every output, stacked above
# the shell's static omarchy-background. Same awk as wallpaper-watchdog.sh.
mpvpaper_layer_healthy() {
    hyprctl layers 2>/dev/null | awk '
        /^Monitor /  { mon = $2 }
        /namespace: mpvpaper(,|$)/            { mpv[mon] = NR; seen = 1 }
        /namespace: omarchy-background(,|$)/  { oma[mon] = NR }
        END {
            if (!seen) exit 1
            for (m in mpv) if (oma[m] > mpv[m]) exit 1
            exit 0
        }'
}

heal_wallpaper() {
    sleep 1  # let output topology settle
    # Nothing to heal onto with zero outputs (undock while the lid is closed,
    # just before the suspend); the monitoradded at resume re-enters this path.
    hyprctl monitors 2>/dev/null | grep -q '^Monitor ' || return
    # Check for an actual wallpaper LAYER, not just a live process. mpvpaper
    # (and swaybg) can survive a dock/lid transition as a running process while
    # losing its output binding — pgrep still finds it, but the screen is black.
    # The old both-dead pgrep check skipped exactly that case, which is what
    # left the external dark on lid-close (2026-07-10).
    # namespace = mpvpaper|swaybg (pre-Quattro) or omarchy-background (the
    # Quattro shell's own image layer). Video themes get the strict check:
    # the shell's static fallback used to satisfy the loose grep while the
    # video was dead (undock→suspend→resume, 2026-08-24), which parked the
    # fallback art on screen until the ~30s watchdog tick.
    if video_expected; then
        mpvpaper_layer_healthy && return
    else
        hyprctl layers 2>/dev/null | grep -qE 'namespace: (mpvpaper|swaybg|omarchy-background)' && return
    fi
    local now; now=$(date +%s)
    (( now - _last_wp_refire < 8 )) && return
    _last_wp_refire=$now
    log "wallpaper layer missing/buried post-event; re-firing theme-set hook"
    omarchy-hook theme-set
}

# The shell (quickshell) sometimes survives a dock transition as a process
# but loses its layer surfaces — the bar disappears even though the process
# is alive (observed 2026-06-10 on the GlassPill bar; same failure mode).
# Check for the omarchy-bar layer surface; if none, restart the shell via
# omarchy-restart-shell. Normal events where the surface survives are no-ops.
heal_shell() {
    hyprctl layers 2>/dev/null | grep -q 'namespace: omarchy-bar' && return
    # The shell loses its layer surfaces when its output is reconfigured during
    # a dock/lid transition and does NOT re-anchor on its own — it needs a
    # restart to repaint. Do it promptly (a grace window just prolongs the dark
    # screen), but debounce with a cooldown: the transition fires a burst of
    # monitor events, and restarting on each one (4x in 5s observed 2026-07-10)
    # kills the shell before it can map its surfaces, so it never comes back.
    # One restart per window; a fresh instance gets the whole window to come up.
    local now; now=$(date +%s)
    (( now - _last_qs_restart < 8 )) && return
    _last_qs_restart=$now
    log "shell has no bar layer post-event; restarting via omarchy-restart-shell"
    omarchy-restart-shell >/dev/null 2>&1
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
        monitoradded*|monitorremoved*) reevaluate; heal_wallpaper; heal_shell ;;
    esac
done

log "socat exited; service will restart"

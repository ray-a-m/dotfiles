#!/usr/bin/env bash
# Safety net for the wallpaper layer. The event-driven heal in
# monitor-watcher.sh only fires on monitoradded/removed, so it misses
# login-race deaths and crashes that land after its one-shot check
# (both observed: sign-in blanks 2026-05-17/18/21; post-dock SIGABRT
# 2026-06-23 that outlived the 1s window). Runs every 30s from
# wallpaper-watchdog.timer; no-ops while the right daemon is alive.
#
# Dual-era (Omarchy 3→4 upgrade):
# - Video backgrounds defer to the theme-set hook (owns the mpvpaper spawn
#   line) in both eras. On Quattro the hook also re-asserts z-order — a
#   respawned mpvpaper surface maps above the shell's static background.
# - Image backgrounds: pre-Quattro respawn swaybg directly (the hook's
#   image branch deliberately no-ops unless mpvpaper is running); on
#   Quattro the omarchy-shell renders images itself and supervises its own
#   surfaces, so there is nothing to heal here.
set -u

pgrep -x Hyprland >/dev/null || exit 0

# Under the user manager WAYLAND_DISPLAY may not be in our env even
# though the session exported it to systemd — same dance as
# monitor-watcher.sh does for the Hyprland socket.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    disp=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p')
    [ -n "$disp" ] || exit 0
    export WAYLAND_DISPLAY="$disp"
fi

# The Quattro health check below calls hyprctl, which needs the instance
# signature — also absent from the unit env. Same recovery as
# monitor-watcher.sh; without it the check always reads "buried" and the
# heal re-fires every 30s (static-image flash over the video).
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    sig=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p' | head -n1)
    [ -n "$sig" ] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"
fi

log() { printf '[wallpaper-watchdog] %s\n' "$*"; }

LEGACY_BG=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null)

if [ -n "${LEGACY_BG:-}" ] && [ -e "$LEGACY_BG" ]; then
    # --- Pre-Quattro path (unchanged behavior) ----------------------------
    ext="${LEGACY_BG##*.}"
    case "${ext,,}" in
        mp4|webm|mkv|mov|avi)
            pgrep -x mpvpaper >/dev/null && exit 0
            log "mpvpaper dead for video background; re-firing theme-set hook"
            omarchy-hook theme-set
            ;;
        *)
            pgrep -x swaybg >/dev/null && exit 0
            log "swaybg dead for image background; respawning"
            setsid uwsm-app -- swaybg -i "$LEGACY_BG" -m fill >/dev/null 2>&1 &
            ;;
    esac
else
    # --- Quattro path -----------------------------------------------------
    # Only video themes need healing (see header). A video is expected when
    # the current theme's user backgrounds dir contains one.
    THEME_NAME=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
    [ -n "${THEME_NAME:-}" ] || exit 0
    VIDEO=$(find -L "$HOME/.config/omarchy/backgrounds/$THEME_NAME/" \
        "$HOME/.local/state/omarchy/current/theme/backgrounds/" -maxdepth 1 -type f \
        \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \) \
        2>/dev/null | head -n1)
    [ -n "${VIDEO:-}" ] || exit 0

    # Healthy = mpvpaper process alive, its layer surface mapped, and on
    # every output stacked above the shell's static background.
    # `hyprctl layers` lists surfaces per monitor, bottom→top within a
    # level, so omarchy-background appearing after mpvpaper on the same
    # monitor means the shell restarted and re-mapped its surface over the
    # video. Re-firing the hook respawns mpvpaper back on top.
    if pgrep -x mpvpaper >/dev/null && hyprctl layers 2>/dev/null | awk '
        /^Monitor /  { mon = $2 }
        /namespace: mpvpaper(,|$)/            { mpv[mon] = NR; seen = 1 }
        /namespace: omarchy-background(,|$)/  { oma[mon] = NR }
        END {
            if (!seen) exit 1
            for (m in mpv) if (oma[m] > mpv[m]) exit 1
            exit 0
        }'; then
        exit 0
    fi
    log "video wallpaper missing/buried; re-firing theme-set hook"
    omarchy-hook theme-set
fi

# We run as a oneshot service: the moment this script exits, systemd
# reaps every process left in the unit's cgroup — including uwsm-app
# before it has moved the wallpaper daemon into its own app scope
# (verified 2026-07-03: heal fired but mpvpaper never appeared without
# this). Linger long enough for the handoff to complete.
sleep 5

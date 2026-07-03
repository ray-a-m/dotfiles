#!/usr/bin/env bash
# Safety net for the wallpaper layer. The event-driven heal in
# monitor-watcher.sh only fires on monitoradded/removed, so it misses
# login-race deaths and crashes that land after its one-shot check
# (both observed: sign-in blanks 2026-05-17/18/21; post-dock SIGABRT
# 2026-06-23 that outlived the 1s window). Runs every 30s from
# wallpaper-watchdog.timer; no-ops while the right daemon is alive.
#
# Video backgrounds defer to the theme-set hook (owns the mpvpaper
# spawn line). Image backgrounds respawn swaybg directly, because the
# hook's image branch deliberately no-ops unless mpvpaper is running.
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

BG=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null)
[ -n "${BG:-}" ] && [ -e "$BG" ] || exit 0

log() { printf '[wallpaper-watchdog] %s\n' "$*"; }

ext="${BG##*.}"
case "${ext,,}" in
    mp4|webm|mkv|mov|avi)
        pgrep -x mpvpaper >/dev/null && exit 0
        log "mpvpaper dead for video background; re-firing theme-set hook"
        "$HOME/.config/omarchy/hooks/theme-set"
        ;;
    *)
        pgrep -x swaybg >/dev/null && exit 0
        log "swaybg dead for image background; respawning"
        setsid uwsm-app -- swaybg -i "$BG" -m fill >/dev/null 2>&1 &
        ;;
esac

# We run as a oneshot service: the moment this script exits, systemd
# reaps every process left in the unit's cgroup — including uwsm-app
# before it has moved the wallpaper daemon into its own app scope
# (verified 2026-07-03: heal fired but mpvpaper never appeared without
# this). Linger long enough for the handoff to complete.
sleep 5

#!/usr/bin/env bash
# Mirror direction helper. Omarchy's omarchy-hyprland-monitor-internal-mirror
# writes the toggle file with EXTERNAL mirroring INTERNAL. With our laptop at
# scale=2 (retina-class) and the external monitor at scale=1, that makes the
# external display the laptop's framebuffer (rendered for 1440x960 logical)
# stretched to its 2560x1440 panel — everything looks ~1.78x zoomed.
#
# These helpers reverse the direction: laptop mirrors external. The external
# renders at its native resolution, and the laptop shows the same content
# downscaled to fit its panel (lower density but readable, and the lid is
# the secondary surface anyway).
#
# Toggle file paths match what `omarchy-hyprland-toggle` reads, so SUPER+CTRL+
# ALT+DEL keeps working — it'll just see a non-empty file and treat the
# state as "mirror on", same as omarchy's own version.

_mirror_toggle="$HOME/.local/state/omarchy/toggles/hypr/internal-monitor-mirror.conf"
_disable_toggle="$HOME/.local/state/omarchy/toggles/hypr/internal-monitor-disable.conf"

# Debounced external-monitor presence check, for the SUSPEND decision only.
# omarchy-hw-external-monitors reads DRM connector status, which momentarily
# reports "disconnected" while the output topology churns during a dock/lid
# transition — heaviest exactly when the lid closes. A single flake there made
# lid.sh / the watcher suspend a *docked* machine, sometimes in a
# suspend->wake->suspend loop until DRM settled (journal 2026-07-10 16:42:59,
# machine actually entered s2idle twice). Poll instead: return "present" (0)
# the instant an external appears, and only conclude "absent" (1) after it
# stays gone for the whole window. The common docked case returns in <0.5s;
# only a genuine unplug pays the full wait before we suspend.
external_present_stable() {
    local i
    for i in $(seq 1 12); do
        omarchy-hw-external-monitors && return 0
        sleep 0.5
    done
    return 1
}

mirror_on() {
    local internal external
    internal=$(hyprctl monitors -j | jq -r '.[] | select(.name | contains("eDP")).name' | head -n 1)
    external=$(hyprctl monitors -j | jq -r '.[] | select(.name | contains("eDP") | not).name' | head -n 1)
    [[ -z $internal || -z $external ]] && return 1

    local desired="monitor=$internal, preferred, auto, auto, mirror, $external"
    # Idempotent: reevaluate() calls mirror_on on every event, and a redundant
    # hyprctl reload re-applies monitor rules (churning outputs → quickshell/
    # wallpaper blink). If we're already mirroring exactly this with no stale
    # disable toggle, do nothing.
    [[ "$(cat "$_mirror_toggle" 2>/dev/null)" == "$desired" && ! -e "$_disable_toggle" ]] && return 0

    # Mirror takes precedence over disable.
    rm -f "$_disable_toggle"
    mkdir -p "$(dirname "$_mirror_toggle")"
    echo "$desired" > "$_mirror_toggle"
    hyprctl reload >/dev/null 2>&1
}

# Disable the internal panel in a SINGLE reload — straight from mirror to
# disabled, skipping the intermediate "eDP-1 independent" state. In that
# intermediate state mpvpaper (its wallpaper globs '*' = every output) spawns a
# second surface on eDP-1; the old two-step lid-close (drop mirror, then disable
# internal via omarchy-hyprland-monitor-internal) disabled eDP-1 mid-spawn, and
# mpvpaper dropped ALL its surfaces — including the external's — so the docked
# display went to a black video wallpaper for seconds (root-caused 2026-07-10 by
# watching layer counts through a decomposed transition). One atomic reload never
# enters the racy state.
internal_off_atomic() {
    local internal
    internal=$(hyprctl monitors all -j | jq -r '.[] | select(.name | contains("eDP")).name' | head -n 1)
    [[ -z $internal ]] && return 1
    rm -f "$_mirror_toggle"
    mkdir -p "$(dirname "$_disable_toggle")"
    echo "monitor=$internal,disable" > "$_disable_toggle"
    hyprctl reload >/dev/null 2>&1
}

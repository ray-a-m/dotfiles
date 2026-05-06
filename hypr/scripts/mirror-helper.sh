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

mirror_on() {
    local internal external
    internal=$(hyprctl monitors -j | jq -r '.[] | select(.name | contains("eDP")).name' | head -n 1)
    external=$(hyprctl monitors -j | jq -r '.[] | select(.name | contains("eDP") | not).name' | head -n 1)
    [[ -z $internal || -z $external ]] && return 1

    # Mirror takes precedence over disable.
    rm -f "$_disable_toggle"
    mkdir -p "$(dirname "$_mirror_toggle")"
    echo "monitor=$internal, preferred, auto, auto, mirror, $external" > "$_mirror_toggle"
    hyprctl reload >/dev/null 2>&1
}

mirror_off() {
    rm -f "$_mirror_toggle"
    hyprctl reload >/dev/null 2>&1
}

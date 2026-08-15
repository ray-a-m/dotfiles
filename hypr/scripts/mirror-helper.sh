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
# Toggle files are Lua, in the names Quattro's toggle loader globs (it reads
# *.lua only; toggles.lua require_all's the directory). The mirror file keeps
# the stock name, so SUPER+CTRL+ALT+DEL still sees "mirror on"; the disable
# state uses the stock clamshell flag, so omarchy-hyprland-monitor-clamshell
# recognizes and clears it on lid-open.

_toggle_dir="$HOME/.local/state/omarchy/toggles/hypr"
_mirror_toggle="$_toggle_dir/internal-monitor-mirror.lua"
_clamshell_toggle="$_toggle_dir/internal-monitor-clamshell.lua"
_disable_toggle="$_toggle_dir/internal-monitor-disable.lua"

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
    internal=$(hyprctl monitors all -j | jq -r '.[] | select(.name | contains("eDP")).name' | head -n 1)
    external=$(hyprctl monitors -j | jq -r '.[] | select(.name | contains("eDP") | not).name' | head -n 1)
    [[ -z $internal || -z $external ]] && return 1

    local desired
    desired=$(printf 'hl.monitor({ output = "%s", mode = "preferred", position = "auto", scale = 1, mirror = "%s" })' "$internal" "$external")
    # Idempotent: reevaluate() calls mirror_on on every event, and a redundant
    # hyprctl reload re-applies monitor rules (churning outputs → shell/
    # wallpaper blink). If we're already mirroring exactly this with no stale
    # disable/clamshell toggle, do nothing.
    [[ "$(cat "$_mirror_toggle" 2>/dev/null)" == "$desired" && ! -e "$_disable_toggle" && ! -e "$_clamshell_toggle" ]] && return 0

    # Mirror takes precedence over disable/clamshell; removing those flags in
    # the same reload also re-enables the internal panel on lid-open.
    local was_disabled=0
    [[ -e "$_disable_toggle" || -e "$_clamshell_toggle" ]] && was_disabled=1
    rm -f "$_disable_toggle" "$_clamshell_toggle"
    mkdir -p "$_toggle_dir"
    echo "$desired" > "$_mirror_toggle"
    hyprctl reload >/dev/null 2>&1
    if (( was_disabled )); then
        hyprctl dispatch "hl.dsp.dpms({ action = \"enable\", monitor = \"$internal\" })" >/dev/null 2>&1
    fi
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
    # Exact stock-clamshell format, so omarchy-hyprland-monitor-clamshell's
    # enable path recognizes the flag and its own writes dedupe against ours.
    local desired
    desired=$(printf 'hl.monitor({ output = "%s", disabled = true })' "$internal")
    # Idempotent, same reasoning as mirror_on: no redundant reload when the
    # flag is already in place (reevaluate fires on every monitor event).
    [[ "$(cat "$_clamshell_toggle" 2>/dev/null)" == "$desired" && ! -e "$_mirror_toggle" ]] && return 0
    rm -f "$_mirror_toggle"
    mkdir -p "$_toggle_dir"
    printf '%s\n' "$desired" > "$_clamshell_toggle"
    hyprctl reload >/dev/null 2>&1
}

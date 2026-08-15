#!/usr/bin/env bash
# Cycle Hyprland monitor scale up or down by a fixed step (default 0.05).
# Used as a per-session display-size knob — bump up on a high-DPI laptop
# panel, bump down on a dock's lower-DPI external. Applies to every enabled
# monitor at once so multi-screen setups stay in sync.
#
# Hyprland requires monitor scale to produce integer logical pixel widths
# (width / scale must be a whole number). Many fractional scales are
# silently rejected on specific resolutions — e.g. 1.5 fails on 2560-wide
# (2560/1.5 = 1706.67). When that happens, Hyprland keeps the prior scale
# and emits no error code. This script reads the post-apply scale back and
# surfaces the mismatch in the notification so the operator knows to try a
# different value rather than stepping past it blindly.
#
# After each scale change, re-run the omarchy theme-set hook: re-keywording
# the monitor destroys mpvpaper's surface (and swaybg's, in non-video
# themes) without re-attaching, so we relaunch the appropriate daemon.
#
# Args:
#   $1 = "up" | "down"  (default: "up")
# Env:
#   HYPR_SCALE_STEP    increment per press (default 0.05)
#   HYPR_SCALE_MIN     lower bound (default 0.5)
#   HYPR_SCALE_MAX     upper bound (default 3.0)

set -euo pipefail

direction="${1:-up}"
step="${HYPR_SCALE_STEP:-0.05}"
min="${HYPR_SCALE_MIN:-0.5}"
max="${HYPR_SCALE_MAX:-3.0}"

mons=$(hyprctl monitors -j | jq -c '[.[] | select(.disabled | not)]')
current=$(jq -r '.[0].scale' <<<"$mons")

# Snap to a step-multiple grid in the requested direction. Without snapping,
# repeated arithmetic drift would push the value off clean increments and
# eventually round into wrong cells (e.g. 1.2499 instead of 1.25).
if [ "$direction" = "up" ]; then
  new=$(awk -v c="$current" -v s="$step" -v m="$max" 'BEGIN{
    n = int((c + s) / s + 0.5) * s
    if (n > m) n = m
    printf "%.2f", n
  }')
else
  new=$(awk -v c="$current" -v s="$step" -v m="$min" 'BEGIN{
    n = int((c - s) / s + 0.5) * s
    if (n < m) n = m
    printf "%.2f", n
  }')
fi

# Preserve each monitor's existing resolution, refresh, and absolute (x,y)
# position — only the scale field changes. `auto` for position would let
# Hyprland re-layout, breaking stable multi-monitor arrangements.
# Quattro Lua provider: `hyprctl keyword` is rejected ("Use eval"), so the
# monitor spec is applied as an hl.monitor(...) expression instead.
jq -r --arg s "$new" \
  '.[] | "hl.monitor({ output = \"\(.name)\", mode = \"\(.width)x\(.height)@\(.refreshRate)\", position = \"\(.x)x\(.y)\", scale = \($s) })"' \
  <<<"$mons" \
  | while read -r expr; do
      hyprctl eval "$expr" >/dev/null
    done

# Read back the scale Hyprland actually settled on. If it differs from our
# request, Hyprland silently rejected the value (almost always because the
# resulting logical width wouldn't be an integer for this resolution).
sleep 0.1
actual=$(hyprctl monitors -j | jq -r '[.[] | select(.disabled | not)][0].scale')
actual_norm=$(printf '%.2f' "$actual")

if [ "$actual_norm" = "$new" ]; then
  msg="→ ${new}x"
else
  msg="${new}x rejected (kept ${actual_norm}x — try a nearby value)"
fi

# Re-keywording monitor destroys the wallpaper surface even when the scale
# value itself was rejected — restart the daemon regardless.
sleep 0.1
"$HOME/.config/omarchy/hooks/theme-set" >/dev/null 2>&1 &
disown

notify-send -t 1500 "Display scale" "$msg"

#!/bin/bash
# Toggle the Music special workspace (special:music).
#
# - If the workspace already has at least one window, plain toggle.
# - If empty, show the workspace and relaunch spotify-player + cmus. The
#   silent windowrules in hypr/windows.conf route them onto special:music,
#   and since we toggled the workspace into view first, they appear in place.
#
# Detection pattern: `hyprctl clients` prints `workspace: <id> (<name>)`,
# so we grep for `(special:music)` — a bare `workspace: special:music`
# grep never matches, and every press would spawn a new window.

# Quattro: the Lua config provider evaluates the dispatch argument as Lua,
# so the classic `togglespecialworkspace music` form is a syntax error.
toggle_music() { hyprctl dispatch 'hl.dsp.workspace.toggle_special("music")'; }

if hyprctl clients | grep -q '(special:music)'; then
    toggle_music
else
    toggle_music
    uwsm-app -- kitty --class spotify-player -e spotify_player &
    # Wait for spotify-player's window to register before launching cmus,
    # so it claims the left half of the tile split. Without this the two
    # kitty launches race and cmus sometimes wins the left slot.
    for _ in $(seq 1 40); do
        hyprctl clients -j | grep -q '"class": "spotify-player"' && break
        sleep 0.05
    done
    uwsm-app -- kitty --class cmus -e cmus &
fi

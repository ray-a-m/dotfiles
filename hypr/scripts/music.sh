#!/bin/bash
# Toggle the Music special workspace (special:music).
#
# - If the workspace already has at least one window, plain toggle.
# - If empty, show the workspace and launch Spotify + cmus. The silent
#   windowrules in hypr/windows.lua route them onto special:music, and
#   since we toggled the workspace into view first, they appear in place.
#
# Spotify is the regular desktop client (the spotify package). The
# spotify-player TUI it replaced was dropped 2026-09-25.
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
    uwsm-app -- spotify &
    uwsm-app -- kitty --class cmus -e cmus &
fi

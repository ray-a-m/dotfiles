#!/bin/bash
# Toggle the Scribbles special workspace (special:notes).
#
# - If the workspace already has at least one window, plain toggle.
# - If empty, launch yazi rooted at ~/Dropbox/scribbles. The (non-silent)
#   windowrule in hypr/windows.conf routes class:notes onto special:notes,
#   which makes Hyprland auto-show the workspace and focus the new window
#   — so no explicit toggle/focus dispatch is needed in the empty branch.
#
# Note on the detection pattern: `hyprctl clients` prints the workspace as
# `workspace: <id> (<name>)`, e.g. `workspace: -99 (special:notes)`. An
# earlier version of this script grepped for `workspace: special:notes`
# which never matched, so every press spawned a new window.

if hyprctl clients | grep -q '(special:notes)'; then
    # Quattro Lua provider: the dispatch argument is evaluated as Lua.
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("notes")'
else
    uwsm-app -- kitty --class notes -e yazi /home/raymond/Dropbox/scribbles &
fi

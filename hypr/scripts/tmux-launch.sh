#!/usr/bin/env bash
# Attach to (or create) the single tmux `Work` session. Bound to Super+Return
# in ~/.config/hypr/bindings.conf. All Hyprland workspaces share this session
# — cycling with <pfx> {/} moves through the same tmux window pool regardless
# of which Hyprland workspace you're on.
#
# `tmux new -A` is the atomic attach-if-exists form.
set -euo pipefail
exec tmux new -A -s Work

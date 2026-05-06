#!/usr/bin/env bash
# Lid-close handler. Omarchy's stock bindl already calls
# `omarchy-hyprland-monitor-internal off` when the lid closes with an external
# attached, but that command is a no-op while the mirror toggle is on — so we
# drop mirror first, then disable internal. With no external, suspend.
# Requires logind to ignore lid events (see /etc/systemd/logind.conf.d/).

source "$(dirname "$0")/mirror-helper.sh"

if omarchy-hw-external-monitors; then
    mirror_off
    omarchy-hyprland-monitor-internal off
else
    systemctl suspend
fi

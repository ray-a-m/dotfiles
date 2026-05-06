#!/usr/bin/env bash
# Lid-open handler. Omarchy's stock bindl re-enables internal via
# `omarchy-hyprland-monitor-internal on`; we add mirroring on top so the
# external resumes mirroring rather than extending.

source "$(dirname "$0")/mirror-helper.sh"

if omarchy-hw-external-monitors; then
    mirror_on
fi

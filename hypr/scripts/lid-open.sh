#!/usr/bin/env bash
# Lid-open handler. Omarchy's stock bindl re-enables internal via
# `omarchy-hyprland-monitor-internal on`; we add mirroring on top so the
# external resumes mirroring rather than extending.

if omarchy-hw-external-monitors; then
    omarchy-hyprland-monitor-internal-mirror on
fi

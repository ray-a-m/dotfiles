#!/usr/bin/env bash
# Lid-open handler, bound to `switch:off:Lid Switch` in ~/.config/hypr/local.lua.
# The stock lid binds are replaced wholesale there, so the open path is on us
# too. Docked, this is a no-op that also repairs a panel that came back enabled
# after a resume; undocked, it brings the panel back.

set -u

source "$(dirname "$0")/monitor-policy.sh"

apply_monitor_policy open

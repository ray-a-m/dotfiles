#!/usr/bin/env bash
# Lid-close handler, bound to `switch:on:Lid Switch` in ~/.config/hypr/local.lua.
# The policy itself lives in monitor-policy.sh; this passes the lid position it
# knows rather than letting the policy read /proc, which can still report "open"
# at the instant the bind fires.

set -u

source "$(dirname "$0")/monitor-policy.sh"

apply_monitor_policy closed

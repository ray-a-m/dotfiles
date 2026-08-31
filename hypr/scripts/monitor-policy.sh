#!/usr/bin/env bash
# Dock policy for Hyprland: what the internal panel does as an external monitor
# comes and goes. Sourced by lid.sh, lid-open.sh and monitor-watcher.sh — the
# only three entry points, and all three call apply_monitor_policy, so the truth
# table lives in exactly one place.
#
#   external present     → internal panel OFF (lid open or closed)
#   lid closed, no ext   → suspend
#   lid open, no ext     → internal panel ON
#
# Why the panel is off while docked with the lid open, instead of mirroring the
# external (what this did until 2026-08-31): a mirrored eDP-1 is still a
# first-class output in Hyprland 0.56. `position = "auto"` parked it to the right
# of the external, and it kept its own active workspace and its own share of the
# workspace set — but it renders the EXTERNAL's picture, so everything on it was
# invisible. Switching to an occupied workspace focused a window nobody could
# see; an empty workspace the mirror sat on could not be destroyed, so the bar
# showed it occupied; and the cursor could walk off the external into a screen
# that does not exist. Omarchy's own mirror toggle (SUPER+CTRL+ALT+DEL) still
# works, but the next monitor event turns the panel back off: this policy owns
# the panel state.
#
# Requires logind to ignore lid events (see /etc/systemd/logind.conf.d/), since
# the lid switch is bound to lid.sh / lid-open.sh in ~/.config/hypr/local.lua.

_toggle_dir="$HOME/.local/state/omarchy/toggles/hypr"
_mirror_toggle="$_toggle_dir/internal-monitor-mirror.lua"
_clamshell_toggle="$_toggle_dir/internal-monitor-clamshell.lua"
_disable_toggle="$_toggle_dir/internal-monitor-disable.lua"

# Toggle files are Lua, in the names Quattro's toggle loader globs (it reads
# *.lua only; toggles.lua require_all's the directory). WHICH file holds the
# panel-off state is load-bearing, because Omarchy runs its own clamshell
# watcher every few seconds:
#   internal-monitor-clamshell.lua is Omarchy's OWN state. Its enable path ("lid
#   open" or "no external") deletes the file and reloads — so with the lid open
#   and the panel deliberately off, the stock watcher fought us and had the panel
#   back within seconds (2026-08-31).
#   internal-monitor-disable.lua is the stock *manual* disable, i.e. "the user
#   meant this". enable_internal() leaves it alone while an external is active,
#   and `omarchy-hyprland-monitor-internal recover` clears it once the external
#   goes away — so the panel returns on undock even if our watcher is dead.
# The panel-off state therefore goes in the manual-disable flag. Sharing that
# flag with stock also keeps SUPER+CTRL+Delete ("Toggle laptop display") honest:
# it reads and reports the same state this policy writes. Pressing it while
# docked turns the panel on until the next monitor event, which turns it off
# again — the policy owns the panel, by design.

# stderr, because that is where each caller's log already goes: the watcher runs
# under systemd (`journalctl --user -u monitor-watcher`), the lid handlers are
# Hyprland binds (Hyprland's own log).
log() { printf '[dock-policy] %s\n' "$*" >&2; }

# Connector names are written into generated Lua, so only a plain name may pass;
# anything else could execute on the next reload. Same guard as stock.
safe_output_name() { [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]; }

internal_output() { omarchy-hyprland-monitor-laptop; }

# Stock, rather than a hardcoded /proc/acpi/button/lid/LID/state: it globs the
# lid device, which is not named the same on every machine.
lid_closed() { omarchy-hw-laptop-closed; }

# Debounced external-monitor presence check, for the SUSPEND decision only.
# omarchy-hw-external-monitors reads DRM connector status, which momentarily
# reports "disconnected" while the output topology churns during a dock/lid
# transition — heaviest exactly when the lid closes. A single flake there made
# lid.sh / the watcher suspend a *docked* machine, sometimes in a
# suspend->wake->suspend loop until DRM settled (journal 2026-07-10 16:42:59,
# machine actually entered s2idle twice). Poll instead: return "present" (0) the
# instant an external appears, and only conclude "absent" (1) after it stays gone
# for the whole window. The common docked case returns in <0.5s; only a genuine
# unplug pays the full wait before we suspend.
external_present_stable() {
    local i
    for i in $(seq 1 12); do
        omarchy-hw-external-monitors && return 0
        sleep 0.5
    done
    return 1
}

# True when Hyprland currently has the internal panel disabled. The toggle file
# records what we ASKED for; this reports what actually took. The two diverge
# after a resume, where Hyprland can come back with a layout that no longer
# matches an unchanged flag file — an idempotence check on the file alone would
# then skip its reload and leave the external unconfigured.
internal_is_disabled() {
    [[ "$(hyprctl monitors all -j | jq -r --arg i "$1" '.[] | select(.name == $i) | .disabled')" == "true" ]]
}

# Disable the internal panel in a SINGLE reload. A decomposed transition — drop
# one rule, reload, write the next, reload — briefly leaves eDP-1 as an
# independent output, and mpvpaper (video wallpaper, globs '*' = every output)
# starts spawning a surface on it; disabling eDP-1 mid-spawn made mpvpaper drop
# ALL its surfaces, including the external's, so the docked display went to a
# black wallpaper for seconds (root-caused 2026-07-10 by watching layer counts
# through a decomposed transition). One reload never enters that state.
internal_off() {
    local internal
    internal=$(internal_output)
    [[ -n $internal ]] || { log "no internal panel found; leaving monitors alone"; return 1; }
    safe_output_name "$internal" || { log "refusing unsafe monitor name: $internal"; return 1; }
    # Never leave the session with no output at all. The external can vanish
    # between the caller's check and this write — a whole class of dock bug, see
    # external_present_stable — and stock refuses the same way.
    omarchy-hyprland-monitor-external-active || { log "no active external; leaving $internal on"; return 1; }

    # Exact stock format, so omarchy-hyprland-monitor-internal's own writes and
    # its recover path dedupe against ours.
    local desired
    desired=$(printf 'hl.monitor({ output = "%s", disabled = true })' "$internal")
    # Idempotent: the policy is applied on every monitor event, and a redundant
    # reload re-applies monitor rules (churning outputs → shell/wallpaper blink).
    # Gated on the live state as well as the file, per internal_is_disabled.
    [[ "$(cat "$_disable_toggle" 2>/dev/null)" == "$desired" && ! -e "$_mirror_toggle" ]] \
        && internal_is_disabled "$internal" && return 0

    # Drop Omarchy's clamshell flag too: same content, but leaving it behind
    # gives the stock watcher a file to delete and reload for on the next lid
    # event — a reload we did not ask for.
    rm -f "$_mirror_toggle" "$_clamshell_toggle"
    mkdir -p "$_toggle_dir"
    printf '%s\n' "$desired" > "$_disable_toggle"
    hyprctl reload >/dev/null 2>&1

    # Verify, and reload once more if the panel is still up. Observed
    # 2026-08-31: a reload issued in the same instant the flag was written left
    # eDP-1 enabled, and a second identical reload seconds later disabled it — so
    # the write is not always visible to the reload that follows it. One retry
    # beats leaving a phantom output on the desk.
    sleep 0.5
    internal_is_disabled "$internal" && return 0
    log "panel still up after reload; retrying"
    hyprctl reload >/dev/null 2>&1
}

# Re-enable the internal panel — undocking, and the lid opening with nothing
# attached, are the only paths that need it.
internal_on() {
    local internal
    internal=$(internal_output)
    if [[ -e $_disable_toggle || -e $_mirror_toggle ]]; then
        # Our flags first: the stock enable path reloads only for its own
        # clamshell flag, so a disable or mirror rule left here would survive
        # that reload and keep the panel dark.
        rm -f "$_disable_toggle" "$_mirror_toggle"
        hyprctl reload >/dev/null 2>&1
        # The reload brings the output back, but a panel disabled while dpms-off
        # stays dark. Wake it only when we actually changed something: an
        # unconditional wake undoes lock-screen blanking (stock guards its own
        # recover path for the same reason).
        [[ -n $internal ]] && safe_output_name "$internal" \
            && hyprctl dispatch "hl.dsp.dpms({ action = \"enable\", monitor = \"$internal\" })" >/dev/null 2>&1
    fi
    # The rest is Omarchy's: clear its clamshell flag if it set one, restore the
    # configured scale, wake the panel. Near no-op when there is nothing to do,
    # which is every monitor event while undocked.
    omarchy-hyprland-monitor-clamshell >/dev/null 2>&1
}

# The whole policy. Callers that KNOW the lid position pass it, because the lid
# binds fire before /proc/acpi/button reliably reflects the new position and a
# misread on close would skip the suspend. The watcher, which has no such
# knowledge, passes nothing and the file is read.
apply_monitor_policy() {
    local lid="${1:-}"
    [[ -n $lid ]] || { lid=open; lid_closed && lid=closed; }

    if [[ $lid == closed ]]; then
        if external_present_stable; then
            log "lid closed + external → panel off"
            internal_off
        else
            log "lid closed + no external → suspending"
            systemctl suspend
        fi
    else
        if omarchy-hw-external-monitors; then
            log "lid open + external → panel off"
            internal_off
        else
            log "lid open + no external → panel on"
            internal_on
        fi
    fi
}

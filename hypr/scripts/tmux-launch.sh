#!/usr/bin/env bash
# Attach to (or create) the single tmux `Work` session. Bound to Super+Return
# in ~/.config/hypr/bindings.conf. All Hyprland workspaces share this session
# — cycling with <pfx> {/} moves through the same tmux window pool regardless
# of which Hyprland workspace you're on.
#
# The server is started in its OWN systemd scope (tmux-server.scope) rather than
# inline. Under uwsm, this terminal lives in a transient kitty-*.scope; a tmux
# server spawned directly inside it inherits that cgroup, and daemonizing
# (double-fork) does NOT escape the cgroup. So closing THIS window with Super+W
# (killactive) would tear down the scope and SIGTERM the server with it —
# killing every session, not just this client. Placing the server in a
# dedicated scope decouples its lifetime from any one window: closing a window
# drops only the client, and the next Super+Return re-attaches.
set -euo pipefail

if ! tmux has-session -t Work 2>/dev/null; then
  # The server is gone, but the scope can still be pinned "active" by a
  # resident wl-copy that a copy inside tmux left holding the clipboard.
  # That stale unit makes systemd-run fail on the name below (window flashes
  # shut). We only reach here with no Work session, so stopping it is safe.
  systemctl --user stop tmux-server.scope 2>/dev/null || true
  systemd-run --user --scope --collect --quiet --unit=tmux-server \
    tmux new-session -d -s Work
fi

exec tmux attach -t Work

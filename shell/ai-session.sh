#!/usr/bin/env bash
# Session entry for the ai LXC's tmux (run by `serverauto` on creation,
# not on reattach). Freshen the multi-homed repos, then hand the
# session to Claude; when Claude exits, drop to a shell instead of
# killing the tmux session.
export PATH="$HOME/.local/bin:$PATH"
# --autostash: pull.rebase is set, and git refuses to rebase over
# unstaged changes even for a fast-forward. RM_CONFIG_PULLED tells
# Claude's SessionStart hook the layer is fresh, so it does not pull
# dotfiles-private again.
for r in "$HOME/code/dotfiles" "$HOME/code/dotfiles-private" "$HOME/code/homelab"; do
    timeout 20 git -C "$r" pull --ff-only --autostash -q 2>/dev/null \
        || echo "stale: $r (pull failed — offline, dirty, or diverged)"
done
# Fullscreen renderer on this box only -- Raymond keeps the laptop on
# the classic TUI, so the preference rides the per-invocation overlay
# instead of the shared settings.json.
RM_CONFIG_PULLED=1 claude --settings '{"tui": "fullscreen"}'
exec zsh

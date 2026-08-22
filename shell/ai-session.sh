#!/usr/bin/env bash
# Session entry for the ai LXC's tmux (run by `serverauto` on creation,
# not on reattach). Freshen the multi-homed repos, then hand the
# session to Claude; when Claude exits, drop to a shell instead of
# killing the tmux session.
export PATH="$HOME/.local/bin:$PATH"
for r in "$HOME/code/dotfiles" "$HOME/code/dotfiles-private" "$HOME/code/homelab"; do
    timeout 20 git -C "$r" pull --ff-only -q 2>/dev/null \
        || echo "stale: $r (pull failed — offline, dirty, or diverged)"
done
claude
exec zsh

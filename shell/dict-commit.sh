#!/usr/bin/env bash
# Commit and push the aspell personal dictionary, and nothing else.
#
# emacs/aspell-personal.pws is a tracked file that ordinary use rewrites:
# every word taken with `i' at an M-$ prompt appends to it. A dirty
# dotfiles tree makes the ff-only pull in `auto' refuse to run, so the
# dictionary commits itself instead of waiting for a hand (2026-08-28).
# Two callers, one behaviour: init.el runs this two idle seconds after
# aspell saves the file, and `auto' runs it before the pull, which
# catches a word taken while the laptop was offline.
#
# What it will not do: the commit is path-limited, so work in progress
# elsewhere in the tree stays uncommitted and unstaged, and the push
# happens only when the dictionary is the only thing waiting to go out.

repo="$HOME/code/dotfiles"
file="emacs/aspell-personal.pws"

[ -d "$repo/.git" ] || exit 0
cd "$repo" || exit 0
[ -f "$file" ] || exit 0

# A partial commit is impossible mid-merge or mid-rebase: leave it alone.
if [ -e .git/MERGE_HEAD ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
    echo "dict: merge or rebase in progress — dictionary left alone"
    exit 0
fi

if ! git diff --quiet -- "$file"; then
    # The message names the words the save added: the added lines of the
    # diff, minus the personal_ws header, whose count changes every time.
    added=$(git diff -U0 -- "$file" \
                | sed -n 's/^+\([^+].*\)$/\1/p' \
                | grep -v '^personal_ws')
    n=$(printf '%s' "$added" | grep -c .)
    words=$(printf '%s\n' "$added" | head -6 | paste -sd, - | sed 's/,/, /g')
    [ "$n" -gt 6 ] && words="$words +$((n - 6)) more"
    msg="aspell: ${words:-dictionary update}"
    if ! git commit -q -m "$msg" -- "$file"; then
        echo "dict: commit failed"
        exit 1
    fi
    committed="$msg"
fi

# Push what is waiting, including a commit an earlier run made while the
# network was down -- but only when the dictionary is all that is
# waiting. Other local work is Raymond's to push, not this script's.
# One line out, whatever happened: `auto' and the echo area both read it.
waiting=$(git diff --name-only '@{u}..HEAD' 2>/dev/null)
if [ -z "$waiting" ]; then
    [ -n "${committed:-}" ] && echo "dict: $committed — committed"
elif [ "$waiting" != "$file" ]; then
    [ -n "${committed:-}" ] && echo "dict: $committed — committed; other work is unpushed, so the push is yours"
elif timeout 20 git push -q 2>/dev/null; then
    echo "dict: ${committed:-a waiting commit} — pushed"
else
    echo "dict: ${committed:-a waiting commit} — push failed (offline or diverged), the commit is local"
fi
exit 0

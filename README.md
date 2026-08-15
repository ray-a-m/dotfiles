# Dotfiles

Personal configuration files for Linux.

## Contents

- **`nvim/`** — Neovim config (LazyVim-based, with LaTeX workflow)
- **`emacs/`** — hand-rolled vanilla Emacs config (not Doom; `use-package`, learning-first). LaTeX (AUCTeX/cdlatex/latexmk/zathura) + Org notes vault (`~/Dropbox/notes`, migrated from Obsidian) + live math (xenops) + prose look (variable-pitch/olivetti). Also the org export engines: `org-paper-export.el` (papers/CV/dissertation → LaTeX) and `org-site-export.el` (raymondmaung.com pages → HTML into research-public). See `emacs/README.md`.
- **`kitty/`** — Kitty terminal config
- **`hypr/`** — Hyprland window manager config (Omarchy 4 "Quattro", Lua; per-file symlinks, machine-specific `monitors.lua` and `local.lua` stay local). Includes `hypr/scripts/` for dock/lid policy.
- **`omarchy/`** — Omarchy customization: `hooks/` and `themes/` (`themes/mornye/` is the active custom theme — Catppuccin Latte palette + animated mp4 wallpaper; `omarchy-theme-set mornye`), `plugins/` (Quattro shell forks: `raymond.bar`, `raymond.menu`, `raymond.tray`, `raymond.lock`, `raymond.workspaces-numpad`), and `shell.json`/`shell.toml` (shell config, installed as copies — the shell rewrites them in place, so live edits must be copied back here).
- **`keyd/`** — keyd remap for the internal ThinkPad keyboard (ralt→ctrl, caps→alt, lalt↔lsuper); deployed to `/etc/keyd/`.
- **`walker/`**, **`swayosd/`**, **`quickshell/`** — pre-Quattro reference only, not installed. Walker/swayosd were retired by Omarchy 4; `quickshell/` is the retired GlassPill bar the `raymond.bar` plugin replaced.
- **`udev/`** — Linux udev rules; currently `99-usb-wakeup.rules` enables wake-on-USB for s2idle suspend (symlinked into `/etc/udev/rules.d/` by `install.sh`).
- **`pacman-hooks/`** — Pacman hooks (deployed to `/etc/pacman.d/hooks/`). Currently: `librewolf-policies.hook` re-runs `librewolf/merge-policies.sh` after a `librewolf-bin` upgrade, so `/etc/librewolf/policies.json` stays a merge of the package defaults and this repo's overlay instead of replacing them wholesale.
- **`systemd/`** — Linux systemd units and sleep hooks. `system/` units land in `/etc/systemd/system/` (root-owned; currently `usb-wakeup.service`); `system-sleep/` scripts land in `/usr/lib/systemd/system-sleep/` (currently `usb-wakeup`, the resume-side companion to the boot-time service); `user/` units land in `~/.config/systemd/user/` and run under the per-user systemd manager (`monitor-watcher.service`, the dock-policy daemon — `Restart=always`, journal logging, replaces the prior `exec-once` wiring so a one-time exit no longer silently kills the policy — plus `wallpaper-watchdog.service`/`.timer` and `emacs.service`). All copied (not symlinked) by `install.sh` since the system loader rejects symlinks resolving into `/home/`.
- **`xdg/`** — preferred-terminal list and default-application MIME mappings
- **`shell/`** — zsh additions (sourced from `~/.zshrc`): `scholarship` / `wip` / `pub` / `dots` aliases, `save` / `publish` / `pdfsplit` functions, and zoxide init. `publish` covers the documents (`cv`, `dissertation`, `<paper-slug>`) and the website (`site`)
- **`texmf/`** — custom `.sty` packages installed into the user TeX tree
- **`install.sh`** — bootstrap script for a new machine

## Setup on a new machine

    git clone git@github.com:ray-a-m/dotfiles.git ~/code/dotfiles
    cd ~/code/dotfiles
    ./install.sh

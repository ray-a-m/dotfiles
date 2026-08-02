# Dotfiles

Personal configuration files for Linux.

## Contents

- **`nvim/`** — Neovim config (LazyVim-based, with LaTeX workflow)
- **`emacs/`** — hand-rolled vanilla Emacs config (not Doom; `use-package`, learning-first). LaTeX (AUCTeX/cdlatex/latexmk/zathura) + Org notes vault (`~/Dropbox/notes`, migrated from Obsidian) + live math (xenops) + prose look (variable-pitch/olivetti). Also the org export engines: `org-paper-export.el` (papers/CV/dissertation → LaTeX) and `org-site-export.el` (raymondmaung.com pages → HTML into research-public). See `emacs/README.md`.
- **`kitty/`** — Kitty terminal config
- **`hypr/`** — Hyprland window manager config (Omarchy; per-file symlinks, machine-specific `monitors.conf` and `local.conf` stay local). Includes `hypr/scripts/` for dock/lid policy.
- **`walker/`**, **`swayosd/`** — Omarchy launcher/OSD configs. Waybar retired; Quickshell is the top bar.
- **`quickshell/`** — Quickshell config (QML). Top-level `shell.qml` entry point + `GlassPill.qml` primitive. Reads the active Omarchy palette from `colors.toml` at startup. Symlinked as one top-level link to `~/.config/quickshell/` (no per-machine override layer, unlike `hypr/`).
- **`omarchy/hooks/`**, **`omarchy/themes/`** — custom Omarchy hooks and themes. `themes/mornye/` is the active custom theme (Catppuccin Latte palette + animated mp4 wallpaper); activate with `omarchy-theme-set mornye`.
- **`udev/`** — Linux udev rules; currently `99-usb-wakeup.rules` enables wake-on-USB for s2idle suspend (symlinked into `/etc/udev/rules.d/` by `install.sh`).
- **`firefox/`** — Profile-side: `user.js` (startup page, sidebar/newtab prefs, userChrome opt-in) and `userChrome.css` (hide chrome, reveal when `[chrome-shown]` attribute is set). `install.sh` finds the active profile via `profiles.ini` and symlinks them in, so the same minimal-UI Firefox follows you to any new machine after a one-time launch. System-side: `autoconfig.js` and `firefox.cfg` (deployed via sudo to `/usr/lib/firefox/`) bind **Ctrl+;** to toggle that attribute. Survives Firefox package upgrades via the pacman hook below.
- **`pacman-hooks/`** — Pacman hooks (deployed to `/etc/pacman.d/hooks/`). Currently: `firefox-userchrome.hook` re-copies the Firefox autoconfig files after `firefox` package upgrades (since pacman wipes `/usr/lib/firefox/` on upgrade).
- **`systemd/`** — Linux systemd units and sleep hooks. `system/` units land in `/etc/systemd/system/` (root-owned; currently `usb-wakeup.service`); `system-sleep/` scripts land in `/usr/lib/systemd/system-sleep/` (currently `usb-wakeup`, the resume-side companion to the boot-time service); `user/` units land in `~/.config/systemd/user/` and run under the per-user systemd manager (currently `monitor-watcher.service`, the dock-policy daemon — `Restart=always`, journal logging, replaces the prior `exec-once` wiring so a one-time exit no longer silently kills the policy). All copied (not symlinked) by `install.sh` since the system loader rejects symlinks resolving into `/home/`.
- **`xdg/`** — preferred-terminal list and default-application MIME mappings
- **`shell/`** — zsh additions (sourced from `~/.zshrc`): `scholarship` / `wip` / `pub` / `dots` aliases, `save` / `publish` / `pdfsplit` functions, and zoxide init. `publish` covers the documents (`cv`, `dissertation`, `<paper-slug>`) and the website (`site`)
- **`latex/`** — custom `.sty` packages installed into the user TeX tree
- **`install.sh`** — bootstrap script for a new machine

## Setup on a new machine

    git clone git@github.com:ray-a-m/dotfiles.git ~/code/dotfiles
    cd ~/code/dotfiles
    ./install.sh

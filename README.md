# Dotfiles

Personal configuration files for macOS and Linux.

## Contents

- **`nvim/`** — Neovim config (LazyVim-based, with LaTeX workflow)
- **`kitty/`** — Kitty terminal config
- **`hypr/`** — Hyprland window manager config (Omarchy; per-file symlinks, machine-specific `monitors.conf` and `local.conf` stay local). Includes `hypr/scripts/` for dock/lid policy.
- **`waybar/`**, **`walker/`**, **`swayosd/`** — Omarchy bar/launcher/OSD configs
- **`omarchy/hooks/`**, **`omarchy/themes/`** — custom Omarchy hooks and themes
- **`applications/`** — `.desktop` files for browser-based apps (Gmail, Drive, Claude, Fastmail, etc.) launched as Chromium PWAs against per-app profiles. Icons in `applications/icons/`.
- **`udev/`** — Linux udev rules; currently `99-usb-wakeup.rules` enables wake-on-USB for s2idle suspend (symlinked into `/etc/udev/rules.d/` by `install.sh`).
- **`xdg/`** — preferred-terminal list and default-application MIME mappings
- **`shell/`** — zsh additions (sourced from `~/.zshrc`): `scholarship` / `wip` / `pub` / `dots` aliases, `save` / `publish` / `pdfsplit` functions, and zoxide init
- **`latex/`** — custom `.sty` packages installed into the user TeX tree
- **`install.sh`** — bootstrap script for a new machine (macOS or Linux)
- **`WORKFLOW.md`** — daily workflow reference
- **`TODO.md`** — outstanding work (cross-platform parity, hardware tests, vendor migrations)

## Setup on a new machine

    git clone https://github.com/<you>/dotfiles.git ~/code/dotfiles
    cd ~/code/dotfiles
    ./install.sh

# Dotfiles

Personal configuration files for macOS and Linux.

## Contents

- **`nvim/`** — Neovim config (LazyVim-based, with LaTeX workflow)
- **`kitty/`** — Kitty terminal config
- **`hypr/`** — Hyprland window manager config (Omarchy; per-file symlinks, machine-specific `monitors.conf` stays local)
- **`waybar/`**, **`walker/`**, **`swayosd/`** — Omarchy bar/launcher/OSD configs
- **`omarchy/hooks/`**, **`omarchy/themes/`** — custom Omarchy hooks and themes
- **`xdg/`** — preferred-terminal list and default-application MIME mappings
- **`shell/`** — zsh additions (sourced from `~/.zshrc`) and starship prompt
- **`latex/`** — custom `.sty` packages installed into the user TeX tree
- **`install.sh`** — bootstrap script for a new machine (macOS or Linux)
- **`WORKFLOW.md`** — daily workflow reference

## Setup on a new machine

    git clone https://github.com/<you>/dotfiles.git ~/code/dotfiles
    cd ~/code/dotfiles
    ./install.sh

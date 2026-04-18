#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing dependencies via Homebrew"
if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Install from https://brew.sh first."
    exit 1
fi

brew install neovim texlab node tree-sitter-cli zoxide gh
brew install --cask ghostty
brew install --cask skim
brew install --cask font-jetbrains-mono-nerd-font

if ! command -v latexmk &>/dev/null; then
    echo "==> latexmk not found; installing MacTeX (this is ~5GB)"
    brew install --cask mactex-no-gui
    echo "==> MacTeX installed. Open a new terminal before continuing."
fi

echo "==> Symlinking nvim config"
mkdir -p ~/.config
if [ -e ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    echo "Backing up existing ~/.config/nvim to ~/.config/nvim.bak"
    mv ~/.config/nvim ~/.config/nvim.bak
fi
ln -sfn "$DOTFILES_DIR/nvim" ~/.config/nvim

echo "==> Done. Launch nvim to finish plugin install."
echo "==> Next steps:"
echo "    1. Set Ghostty font to 'JetBrainsMono Nerd Font' at 11pt (via ~/.config/ghostty/config)"
echo "    2. Add shell aliases and zoxide init (see WORKFLOW.md)"

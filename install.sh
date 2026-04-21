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

echo "==> Symlinking ghostty config"
GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config.ghostty"
mkdir -p "$GHOSTTY_CONFIG_DIR"
if [ -e "$GHOSTTY_CONFIG_FILE" ] && [ ! -L "$GHOSTTY_CONFIG_FILE" ]; then
    echo "Backing up existing $GHOSTTY_CONFIG_FILE to $GHOSTTY_CONFIG_FILE.bak"
    mv "$GHOSTTY_CONFIG_FILE" "$GHOSTTY_CONFIG_FILE.bak"
fi
ln -sfn "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_CONFIG_FILE"

echo "==> Installing LaTeX packages from latex/ into user TeX tree"
case "$(uname -s)" in
    Darwin) TEXMF_ROOT="$HOME/Library/texmf" ;;
    *)      TEXMF_ROOT="$HOME/texmf" ;;
esac
if compgen -G "$DOTFILES_DIR/latex/*.sty" > /dev/null; then
    for sty in "$DOTFILES_DIR"/latex/*.sty; do
        name="$(basename "$sty" .sty)"
        pkg_dir="$TEXMF_ROOT/tex/latex/$name"
        mkdir -p "$pkg_dir"
        ln -sfn "$sty" "$pkg_dir/$name.sty"
        echo "Linked $name.sty -> $pkg_dir/"
    done
    if command -v mktexlsr &>/dev/null; then
        mktexlsr "$TEXMF_ROOT"
    elif command -v texhash &>/dev/null; then
        texhash "$TEXMF_ROOT"
    else
        echo "Neither mktexlsr nor texhash found; skipping ls-R refresh."
    fi
else
    echo "No .sty files in latex/; skipping."
fi

echo "==> Wiring shell additions into ~/.zshrc"
SHELL_SOURCE_LINE='source "$HOME/code/dotfiles/shell/zshrc-additions.sh"'
touch ~/.zshrc
if ! grep -Fxq "$SHELL_SOURCE_LINE" ~/.zshrc; then
    echo "$SHELL_SOURCE_LINE" >> ~/.zshrc
    echo "Added shell additions line to ~/.zshrc"
else
    echo "Shell additions line already present in ~/.zshrc"
fi

echo "==> Done. Launch nvim to finish plugin install."
echo "==> Remaining manual steps:"
echo "    1. Run 'gh auth login' to authenticate GitHub CLI"
echo "    2. Set up Zotero and the Better BibTeX (BBT) extension"

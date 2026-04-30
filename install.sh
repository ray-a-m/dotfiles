#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

install_macos_deps() {
    echo "==> Installing dependencies via Homebrew"
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Install from https://brew.sh first."
        exit 1
    fi

    brew install neovim texlab node tree-sitter-cli zoxide gh
    brew install --cask skim kitty
    brew install --cask font-jetbrains-mono-nerd-font font-blex-mono-nerd-font

    if ! command -v latexmk &>/dev/null; then
        echo "==> latexmk not found; installing MacTeX (this is ~5GB)"
        brew install --cask mactex-no-gui
        echo "==> MacTeX installed. Open a new terminal before continuing."
    fi
}

detect_linux_pm() {
    if command -v apt-get &>/dev/null; then echo apt
    elif command -v dnf &>/dev/null; then echo dnf
    elif command -v pacman &>/dev/null; then echo pacman
    elif command -v zypper &>/dev/null; then echo zypper
    else echo ""
    fi
}

install_linux_deps() {
    local pm
    pm="$(detect_linux_pm)"
    if [ -z "$pm" ]; then
        echo "No supported package manager found (apt/dnf/pacman/zypper)."
        echo "Install manually: neovim nodejs+npm zoxide gh zathura texlive (with latexmk) texlab"
        exit 1
    fi
    echo "==> Detected package manager: $pm"

    case "$pm" in
        apt)
            sudo apt-get update
            sudo apt-get install -y neovim nodejs npm zoxide zathura texlive-full texlab kitty
            if ! command -v gh &>/dev/null; then
                echo "==> gh not in default apt repos; see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            fi
            ;;
        dnf)
            sudo dnf install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full texlab kitty
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                neovim nodejs npm zoxide github-cli zathura zathura-pdf-mupdf texlive-meta texlab kitty
            ;;
        zypper)
            sudo zypper install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full kitty
            command -v texlab &>/dev/null || \
                echo "==> texlab not in zypper repos; install from https://github.com/latex-lsp/texlab/releases"
            ;;
    esac

    if command -v npm &>/dev/null && ! command -v tree-sitter &>/dev/null; then
        echo "==> Installing tree-sitter-cli via npm"
        sudo npm install -g tree-sitter-cli
    fi

    echo "==> Nerd Fonts are not in standard Linux repos."
    echo "    Install manually from https://github.com/ryanoasis/nerd-fonts/releases/latest:"
    echo "      - JetBrainsMono.zip"
    echo "      - IBMPlexMono.zip  (patched name: 'BlexMono Nerd Font' — used by kitty)"
}

case "$OS" in
    Darwin) install_macos_deps ;;
    Linux)  install_linux_deps ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

echo "==> Symlinking nvim config"
mkdir -p ~/.config
if [ -e ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    echo "Backing up existing ~/.config/nvim to ~/.config/nvim.bak"
    mv ~/.config/nvim ~/.config/nvim.bak
fi
ln -sfn "$DOTFILES_DIR/nvim" ~/.config/nvim

echo "==> Symlinking kitty config"
if [ -e ~/.config/kitty ] && [ ! -L ~/.config/kitty ]; then
    echo "Backing up existing ~/.config/kitty to ~/.config/kitty.bak"
    mv ~/.config/kitty ~/.config/kitty.bak
fi
ln -sfn "$DOTFILES_DIR/kitty" ~/.config/kitty

echo "==> Installing LaTeX packages from latex/ into user TeX tree"
case "$OS" in
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

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
    brew install --cask skim kitty firefox
    brew install --cask font-jetbrains-mono-nerd-font font-blex-mono-nerd-font font-monaspace-nerd-font

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
            sudo apt-get install -y neovim nodejs npm zoxide zathura texlive-full texlab kitty firefox-esr
            if ! command -v gh &>/dev/null; then
                echo "==> gh not in default apt repos; see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            fi
            ;;
        dnf)
            sudo dnf install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full texlab kitty firefox
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                neovim nodejs npm zoxide github-cli zathura zathura-pdf-mupdf texlive-meta texlab kitty firefox spotify-player
            ;;
        zypper)
            sudo zypper install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full kitty MozillaFirefox
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

if [ -d "$DOTFILES_DIR/spotify-player" ]; then
    echo "==> Symlinking spotify-player config"
    mkdir -p ~/.config/spotify-player
    for src in "$DOTFILES_DIR"/spotify-player/*; do
        [ -e "$src" ] || continue
        ln -sfn "$src" ~/.config/spotify-player/"$(basename "$src")"
    done
fi

echo "==> Symlinking Claude Code user instructions"
mkdir -p ~/.claude
if [ -e ~/.claude/CLAUDE.md ] && [ ! -L ~/.claude/CLAUDE.md ]; then
    echo "Backing up existing ~/.claude/CLAUDE.md to ~/.claude/CLAUDE.md.bak"
    mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
fi
ln -sfn "$DOTFILES_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md

echo "==> Symlinking XDG default-application files"
for f in xdg-terminals.list mimeapps.list; do
    src="$DOTFILES_DIR/xdg/$f"
    dst="$HOME/.config/$f"
    [ -e "$src" ] || continue
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%s)"
        echo "Backed up $dst"
    fi
    ln -sfn "$src" "$dst"
done

# Per-file symlinks for Omarchy app configs. Per-file (rather than dir-level)
# because we want machine-specific files like ~/.config/hypr/monitors.conf to
# stay locally owned, and we want Omarchy to keep adding new files alongside ours.
echo "==> Symlinking Omarchy app configs (hypr, waybar, walker, swayosd)"
for app in hypr waybar walker swayosd; do
    src_dir="$DOTFILES_DIR/$app"
    dst_dir="$HOME/.config/$app"
    [ -d "$src_dir" ] || continue
    mkdir -p "$dst_dir"
    for src in "$src_dir"/*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        dst="$dst_dir/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "$dst.bak.$(date +%s)"
            echo "Backed up $dst"
        fi
        ln -sfn "$src" "$dst"
    done
done

echo "==> Ensuring per-machine Hyprland override file exists"
touch ~/.config/hypr/local.conf

if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/udev" ]; then
    echo "==> Symlinking udev rules into /etc/udev/rules.d/"
    for src in "$DOTFILES_DIR"/udev/*.rules; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        dst="/etc/udev/rules.d/$name"
        sudo ln -sfn "$src" "$dst"
    done
    echo "==> Reloading udev rules"
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=usb --action=add
fi

if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/systemd" ]; then
    if [ -d "$DOTFILES_DIR/systemd/system" ]; then
        echo "==> Symlinking systemd units"
        for src in "$DOTFILES_DIR"/systemd/system/*.service; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            sudo ln -sfn "$src" "/etc/systemd/system/$name"
        done
        sudo systemctl daemon-reload
        for src in "$DOTFILES_DIR"/systemd/system/*.service; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            sudo systemctl enable --now "$name" 2>/dev/null || true
        done
    fi
    if [ -d "$DOTFILES_DIR/systemd/system-sleep" ]; then
        echo "==> Symlinking systemd sleep hooks"
        for src in "$DOTFILES_DIR"/systemd/system-sleep/*; do
            [ -e "$src" ] || continue
            chmod +x "$src" 2>/dev/null
            name="$(basename "$src")"
            sudo ln -sfn "$src" "/usr/lib/systemd/system-sleep/$name"
        done
    fi
fi

if [ -d "$DOTFILES_DIR/applications" ]; then
    echo "==> Symlinking PWA .desktop files into ~/.local/share/applications/"
    mkdir -p ~/.local/share/applications
    for src in "$DOTFILES_DIR"/applications/*.desktop; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        dst="$HOME/.local/share/applications/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "$dst.bak.$(date +%s)"
            echo "Backed up $dst"
        fi
        ln -sfn "$src" "$dst"
    done
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database ~/.local/share/applications &>/dev/null || true
    fi

    if [ -d "$DOTFILES_DIR/applications/icons" ]; then
        echo "==> Symlinking PWA icons into hicolor theme"
        ICON_DST="$HOME/.local/share/icons/hicolor/256x256/apps"
        mkdir -p "$ICON_DST"
        for src in "$DOTFILES_DIR"/applications/icons/*.png; do
            [ -e "$src" ] || continue
            name="$(basename "$src" .png)"
            ln -sfn "$src" "$ICON_DST/webapp-$name.png"
        done
        if command -v gtk-update-icon-cache &>/dev/null; then
            gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &>/dev/null || true
        fi
    fi
fi

if [ "$OS" = "Linux" ]; then
    if command -v omarchy-install-chromium-google-account &>/dev/null; then
        # The omarchy script no-ops if chromium-flags.conf doesn't exist yet
        # (Chromium creates it on first launch). On a fresh machine we want
        # the OAuth creds in place BEFORE first launch, so seed the file.
        echo "==> Ensuring Chromium can sign in to Google accounts"
        touch ~/.config/chromium-flags.conf
        omarchy-install-chromium-google-account
    fi
    if command -v omarchy-install-dropbox &>/dev/null && \
       command -v pacman &>/dev/null && \
       ! pacman -Q dropbox &>/dev/null; then
        echo "==> Installing Dropbox (will need browser auth after)"
        omarchy-install-dropbox
    fi
    # Extra packages I always want present on an Omarchy box. Aether is in
    # the omarchy pacman repo (theme creator); zoom is AUR-only.
    if command -v omarchy-pkg-add &>/dev/null; then
        echo "==> Ensuring Aether (Omarchy theme creator) is installed"
        omarchy-pkg-add aether
    fi
    if command -v yay &>/dev/null && ! pacman -Q zoom &>/dev/null; then
        echo "==> Installing Zoom from AUR"
        yay -S --noconfirm zoom
    fi
fi

echo "==> Symlinking custom Omarchy hooks, themes, and extensions"
for sub in hooks themes extensions; do
    src_dir="$DOTFILES_DIR/omarchy/$sub"
    dst_dir="$HOME/.config/omarchy/$sub"
    [ -d "$src_dir" ] || continue
    mkdir -p "$dst_dir"
    for src in "$src_dir"/*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        dst="$dst_dir/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "$dst.bak.$(date +%s)"
        fi
        ln -sfn "$src" "$dst"
    done
done

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

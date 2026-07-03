#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

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
            sudo apt-get install -y neovim nodejs npm zoxide zathura texlive-full texlab kitty zsh zsh-autosuggestions zsh-syntax-highlighting
            if ! command -v gh &>/dev/null; then
                echo "==> gh not in default apt repos; see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            fi
            ;;
        dnf)
            sudo dnf install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full texlab kitty zsh zsh-autosuggestions zsh-syntax-highlighting
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                neovim nodejs npm zoxide github-cli zathura zathura-pdf-mupdf texlive-meta texlab kitty spotify-player cmus yazi glow jq quickshell \
                pandoc-cli qpdf obsidian ttf-jetbrains-mono-nerd \
                zsh zsh-autosuggestions zsh-syntax-highlighting \
                bitwarden bitwarden-cli
            ;;
        zypper)
            sudo zypper install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full kitty zsh zsh-autosuggestions zsh-syntax-highlighting
            command -v texlab &>/dev/null || \
                echo "==> texlab not in zypper repos; install from https://github.com/latex-lsp/texlab/releases"
            ;;
    esac

    if command -v npm &>/dev/null && ! command -v tree-sitter &>/dev/null; then
        echo "==> Installing tree-sitter-cli via npm"
        sudo npm install -g tree-sitter-cli
    fi

    if [ "$pm" != "pacman" ]; then
        echo "==> JetBrainsMono Nerd Font (kitty/quickshell/swayosd) comes from pacman on Arch;"
        echo "    on $pm install JetBrainsMono.zip manually from"
        echo "    https://github.com/ryanoasis/nerd-fonts/releases/latest"
    fi
}

case "$OS" in
    Linux)  install_linux_deps ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Vendored fonts: DepartureMono isn't packaged by any distro. JetBrainsMono
# Nerd Font comes from the package manager (ttf-jetbrains-mono-nerd) above.
if [ -d "$DOTFILES_DIR/fonts" ]; then
    echo "==> Installing vendored fonts"
    mkdir -p ~/.local/share/fonts
    cp -rf "$DOTFILES_DIR/fonts/"* ~/.local/share/fonts/
    command -v fc-cache &>/dev/null && fc-cache -f &>/dev/null || true
fi

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

echo "==> Symlinking zathura config"
if [ -e ~/.config/zathura ] && [ ! -L ~/.config/zathura ]; then
    echo "Backing up existing ~/.config/zathura to ~/.config/zathura.bak"
    mv ~/.config/zathura ~/.config/zathura.bak
fi
ln -sfn "$DOTFILES_DIR/zathura" ~/.config/zathura

echo "==> Symlinking yazi config"
if [ -e ~/.config/yazi ] && [ ! -L ~/.config/yazi ]; then
    echo "Backing up existing ~/.config/yazi to ~/.config/yazi.bak"
    mv ~/.config/yazi ~/.config/yazi.bak
fi
ln -sfn "$DOTFILES_DIR/yazi" ~/.config/yazi
if command -v ya &>/dev/null; then
    echo "==> Installing yazi plugins from package.toml"
    ya pkg install
fi

# Quickshell uses a single top-level symlink (no machine-local override
# needed, unlike hypr/). RICING.md §Quickshell.
if [ -d "$DOTFILES_DIR/quickshell" ]; then
    echo "==> Symlinking quickshell config"
    if [ -e ~/.config/quickshell ] && [ ! -L ~/.config/quickshell ]; then
        echo "Backing up existing ~/.config/quickshell to ~/.config/quickshell.bak"
        mv ~/.config/quickshell ~/.config/quickshell.bak
    fi
    ln -sfn "$DOTFILES_DIR/quickshell" ~/.config/quickshell
fi

if [ -d "$DOTFILES_DIR/spotify-player" ]; then
    echo "==> Symlinking spotify-player config"
    mkdir -p ~/.config/spotify-player
    for src in "$DOTFILES_DIR"/spotify-player/*; do
        [ -e "$src" ] || continue
        ln -sfn "$src" ~/.config/spotify-player/"$(basename "$src")"
    done
fi

if [ -d "$DOTFILES_DIR/cmus" ]; then
    echo "==> Symlinking cmus config"
    mkdir -p ~/.config/cmus
    for src in "$DOTFILES_DIR"/cmus/*; do
        [ -e "$src" ] || continue
        ln -sfn "$src" ~/.config/cmus/"$(basename "$src")"
    done
fi

echo "==> Symlinking Claude Code user instructions"
mkdir -p ~/.claude
if [ -e ~/.claude/CLAUDE.md ] && [ ! -L ~/.claude/CLAUDE.md ]; then
    echo "Backing up existing ~/.claude/CLAUDE.md to ~/.claude/CLAUDE.md.bak"
    mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
fi
ln -sfn "$DOTFILES_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md

if [ -e ~/.claude/settings.json ] && [ ! -L ~/.claude/settings.json ]; then
    echo "Backing up existing ~/.claude/settings.json to ~/.claude/settings.json.bak"
    mv ~/.claude/settings.json ~/.claude/settings.json.bak
fi
ln -sfn "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json

if [ -d "$DOTFILES_DIR/claude/skills" ]; then
    echo "==> Symlinking Claude Code skills"
    mkdir -p ~/.claude/skills
    for src in "$DOTFILES_DIR"/claude/skills/*/; do
        [ -d "$src" ] || continue
        ln -sfn "${src%/}" ~/.claude/skills/"$(basename "$src")"
    done
fi

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
# waybar dropped 2026-05-24: the Quickshell shell at ~/.config/quickshell/
# replaces it entirely. Disabling is via ~/.local/state/omarchy/toggles/waybar-off
# (created by this script below); the upstream omarchy autostart sees that
# flag and skips spawning waybar.
echo "==> Symlinking Omarchy app configs (hypr, walker, swayosd)"
for app in hypr walker swayosd; do
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

echo "==> Suppressing waybar autostart (Quickshell takes over)"
# Omarchy's default ~/.local/share/omarchy/default/hypr/autostart.conf only
# spawns waybar when this flag file is absent. We migrated to Quickshell
# 2026-05-24 so flip the toggle on; the file's existence is all that's
# checked (contents irrelevant).
mkdir -p ~/.local/state/omarchy/toggles
touch ~/.local/state/omarchy/toggles/waybar-off

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

if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/bin" ]; then
    echo "==> Installing scripts from bin/ into /usr/local/bin/"
    for src in "$DOTFILES_DIR"/bin/*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        sudo install -Dm 755 "$src" "/usr/local/bin/$name"
    done
fi

if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/systemd" ]; then
    if [ -d "$DOTFILES_DIR/systemd/system" ]; then
        # Copy (not symlink) the unit files. systemd's unit loader rejects
        # symlinks in /etc/systemd/system/ that resolve into /home/, so the
        # symlinked unit silently fails to load at boot (LoadState=not-found
        # despite is-enabled=enabled). The dotfile is still authoritative;
        # re-run install.sh after editing to push the snapshot into /etc/.
        echo "==> Installing systemd units (copy, not symlink)"
        for src in "$DOTFILES_DIR"/systemd/system/*.service "$DOTFILES_DIR"/systemd/system/*.timer; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            # Replace any prior symlink so cp doesn't refuse on same-file.
            sudo rm -f "/etc/systemd/system/$name" \
                "/etc/systemd/system/multi-user.target.wants/$name" \
                "/etc/systemd/system/timers.target.wants/$name"
            sudo cp "$src" "/etc/systemd/system/$name"
        done
        sudo systemctl daemon-reload
        for src in "$DOTFILES_DIR"/systemd/system/*.service "$DOTFILES_DIR"/systemd/system/*.timer; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            sudo systemctl enable --now "$name" 2>/dev/null || true
        done
    fi
    if [ -d "$DOTFILES_DIR/systemd/system-sleep" ]; then
        # Sleep hooks are executed scripts, not parsed by systemd's unit
        # loader, so symlinks here work — but we copy for consistency with
        # the unit-file flow.
        echo "==> Installing systemd sleep hooks (copy, not symlink)"
        for src in "$DOTFILES_DIR"/systemd/system-sleep/*; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            sudo rm -f "/usr/lib/systemd/system-sleep/$name"
            sudo cp "$src" "/usr/lib/systemd/system-sleep/$name"
            sudo chmod +x "/usr/lib/systemd/system-sleep/$name"
        done
    fi
    if [ -d "$DOTFILES_DIR/systemd/user" ]; then
        # User units run under the per-user systemd manager; install into
        # ~/.config/systemd/user/. No sudo, no /etc/ load-from-/home
        # restriction, but copy (not symlink) for consistency with the
        # system-level flow above.
        echo "==> Installing systemd user units"
        USER_UNIT_DIR="$HOME/.config/systemd/user"
        mkdir -p "$USER_UNIT_DIR"
        for src in "$DOTFILES_DIR"/systemd/user/*.service "$DOTFILES_DIR"/systemd/user/*.timer; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            rm -f "$USER_UNIT_DIR/$name"
            cp "$src" "$USER_UNIT_DIR/$name"
        done
        systemctl --user daemon-reload 2>/dev/null || true
        for src in "$DOTFILES_DIR"/systemd/user/*.service "$DOTFILES_DIR"/systemd/user/*.timer; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            systemctl --user enable --now "$name" 2>/dev/null || true
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
fi

# Pacman hooks: redeploy system-side artifacts that pacman wipes when
# upstream packages upgrade. Currently used for the LibreWolf policies
# merge (librewolf-policies.hook). Hooks run /bin/sh -c with hardcoded
# dotfile paths — pacman runs them as root with no usable environment,
# so $HOME / $DOTFILES_DIR cannot be expanded inside the hook file.
if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/pacman-hooks" ]; then
    echo "==> Installing pacman hooks"
    for src in "$DOTFILES_DIR"/pacman-hooks/*.hook; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        sudo install -Dm644 "$src" "/etc/pacman.d/hooks/$name"
    done
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
    # mpvpaper is required by omarchy/hooks/theme-set for any theme whose
    # wallpaper is a video (e.g. blue-girl's mornye mp4). Without it the
    # hook silently fails and the wallpaper layer goes blank.
    if command -v yay &>/dev/null && ! pacman -Q mpvpaper &>/dev/null; then
        echo "==> Installing mpvpaper from AUR"
        yay -S --noconfirm mpvpaper
    fi
    # Daily-driver apps that live in the AUR: Zotero (research library),
    # basilk (task board), rencal (calendar TUI).
    if command -v yay &>/dev/null && ! pacman -Q zotero-bin &>/dev/null; then
        echo "==> Installing Zotero from AUR"
        yay -S --noconfirm zotero-bin
    fi
    if command -v yay &>/dev/null && ! pacman -Q basilk &>/dev/null; then
        echo "==> Installing basilk from AUR"
        yay -S --noconfirm basilk
    fi
    if command -v yay &>/dev/null && ! pacman -Q rencal-bin &>/dev/null; then
        echo "==> Installing rencal from AUR"
        yay -S --noconfirm rencal-bin
    fi
    # firefox-pwa hosts the subset of omarchy-menu PWAs whose upstreams
    # publish a manifest and don't block non-Chromium browsers (currently
    # Claude, ChatGPT, GitHub, Fastmail) so external links open in the
    # default browser (LibreWolf) instead of being trapped in a Chromium
    # app window. The
    # rest (Gmail, Drive, WordPress, UIC services) stay on Chromium —
    # Google blocks firefoxpwa with a 400, the others have no manifest.
    # pwa-setup creates the Personal profile, drops userChrome+user.js,
    # and registers each PWA. Idempotent — safe to re-run.
    if command -v yay &>/dev/null && ! pacman -Q firefox-pwa &>/dev/null; then
        echo "==> Installing firefox-pwa from AUR"
        yay -S --noconfirm firefox-pwa
    fi
    if command -v firefoxpwa &>/dev/null && command -v pwa-setup &>/dev/null; then
        echo "==> Registering firefoxpwa profiles + PWAs"
        pwa-setup
    fi
    if command -v yay &>/dev/null && ! pacman -Q librewolf-bin &>/dev/null; then
        echo "==> Installing LibreWolf from AUR"
        yay -S --noconfirm librewolf-bin
    fi
    # Bitwarden auto-install policy for LibreWolf. The merge script reads
    # LibreWolf's shipped /usr/lib/librewolf/distribution/policies.json
    # (which carries its hardening defaults), overlays dotfiles/librewolf/
    # policies-overlay.json (Bitwarden extension), and writes the union to
    # /etc/librewolf/policies/policies.json. The pacman hook installed
    # earlier re-runs this on every librewolf-bin upgrade.
    if [ -f /usr/lib/librewolf/distribution/policies.json ] && \
       [ -x "$DOTFILES_DIR/librewolf/merge-policies.sh" ]; then
        echo "==> Merging LibreWolf policies (Bitwarden auto-install)"
        "$DOTFILES_DIR/librewolf/merge-policies.sh"
    fi
fi

echo "==> Symlinking custom Omarchy hooks, themes, themed, and extensions"
for sub in hooks themes themed extensions; do
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

echo "==> Refreshing TeX ls-R cache for dotfiles texmf tree"
# TEXMFHOME points directly at dotfiles/texmf/ via rc-additions.sh and the
# Hyprland env block. The tree is committed as-is — no per-machine symlink
# scaffolding needed. Only the regenerable ls-R cache is gitignored and
# rebuilt here on each install.
TEXMF_ROOT="$DOTFILES_DIR/texmf"
if [ -d "$TEXMF_ROOT/tex" ]; then
    if command -v mktexlsr &>/dev/null; then
        mktexlsr "$TEXMF_ROOT"
    elif command -v texhash &>/dev/null; then
        texhash "$TEXMF_ROOT"
    else
        echo "Neither mktexlsr nor texhash found; skipping ls-R refresh."
    fi
else
    echo "No texmf/tex/ tree; skipping ls-R refresh."
fi

echo "==> Wiring shell additions into ~/.zshrc and ~/.bashrc"
SHELL_SOURCE_LINE='source "$HOME/code/dotfiles/shell/rc-additions.sh"'
for rc in ~/.zshrc ~/.bashrc; do
    touch "$rc"
    if ! grep -Fxq "$SHELL_SOURCE_LINE" "$rc"; then
        echo "$SHELL_SOURCE_LINE" >> "$rc"
        echo "Added shell additions line to $rc"
    else
        echo "Shell additions line already present in $rc"
    fi
done

# Set zsh as login shell if it isn't already.
if [ "$OS" = "Linux" ] && command -v zsh >/dev/null; then
    ZSH_PATH="$(command -v zsh)"
    if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
        echo "==> Setting zsh as login shell (chsh -s $ZSH_PATH)"
        echo "    You will be prompted for your password; takes effect on next login."
        chsh -s "$ZSH_PATH" || echo "    chsh failed; run it manually."
    fi
fi

echo "==> Done. Launch nvim to finish plugin install."
echo "==> Remaining manual steps:"
echo "    1. Run 'gh auth login' to authenticate GitHub CLI"
echo "    2. Set up Zotero and the Better BibTeX (BBT) extension"

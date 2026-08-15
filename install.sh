#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

PRUNED_COUNT=0

# Delete symlinks in DIR that point into REPO but no longer resolve.
#
# This script only ever CREATED links, so a source file that gets renamed,
# deleted, or moved to another repo left its old link behind, pointing at
# nothing. Those orphans fail silently, which makes them nasty: on
# 2026-08-02, bin/ moved to dotfiles-private and ~/.local/bin/pwa-launch
# was left dangling, so every PWA launcher did nothing when clicked.
#
# Deliberately narrow. A link is removed only when it is BOTH broken AND
# owned by this repo, so a working link is never touched and neither is
# anything another program put there. Pass "sudo" as RUNNER for root dirs;
# sudo then runs only if there is something to delete, so no password is
# requested on a clean pass.
prune_orphan_links() {
    local dir="$1" repo="$2" runner="${3:-}"
    [ -d "$dir" ] || return 0
    local link target
    for link in "$dir"/* "$dir"/.[!.]*; do
        [ -L "$link" ] || continue      # not a symlink (or an unmatched glob)
        [ -e "$link" ] && continue      # still resolves — leave it alone
        target="$(readlink "$link")"
        case "$target" in
            "$repo"/*)
                $runner rm -f "$link"
                echo "    pruned orphan: $link -> $target"
                PRUNED_COUNT=$((PRUNED_COUNT + 1))
                ;;
        esac
    done
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
            sudo apt-get install -y neovim nodejs npm zoxide zathura texlive-full texlab kitty tmux jq zsh zsh-autosuggestions zsh-syntax-highlighting
            if ! command -v gh &>/dev/null; then
                echo "==> gh not in default apt repos; see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            fi
            ;;
        dnf)
            sudo dnf install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full texlab kitty tmux jq zsh zsh-autosuggestions zsh-syntax-highlighting
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm \
                neovim emacs-wayland nodejs-lts-jod npm zoxide fzf github-cli zathura zathura-pdf-mupdf texlive-meta texlab kitty tmux spotify-player cmus yazi glow jq ddgr quickshell eza keyd \
                pandoc-cli qpdf aspell aspell-en ttf-jetbrains-mono-nerd ttf-liberation ttf-roboto-mono \
                zsh zsh-autosuggestions zsh-syntax-highlighting \
                bitwarden bitwarden-cli
            ;;
        zypper)
            sudo zypper install -y neovim nodejs npm zoxide gh zathura texlive-scheme-full kitty tmux jq zsh zsh-autosuggestions zsh-syntax-highlighting
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

# Vendored fonts: DepartureMono and Atkinson Hyperlegible (Next = Emacs prose
# proportional; Mono) aren't packaged by any distro. JetBrainsMono Nerd Font
# comes from the package manager (ttf-jetbrains-mono-nerd) above.
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

echo "==> Symlinking emacs config"
if [ -e ~/.config/emacs ] && [ ! -L ~/.config/emacs ]; then
    echo "Backing up existing ~/.config/emacs to ~/.config/emacs.bak"
    mv ~/.config/emacs ~/.config/emacs.bak
fi
ln -sfn "$DOTFILES_DIR/emacs" ~/.config/emacs

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

echo "==> Symlinking tmux config"
if [ -e ~/.config/tmux ] && [ ! -L ~/.config/tmux ]; then
    echo "Backing up existing ~/.config/tmux to ~/.config/tmux.bak"
    mv ~/.config/tmux ~/.config/tmux.bak
fi
ln -sfn "$DOTFILES_DIR/tmux" ~/.config/tmux
if [ ! -d ~/.tmux/plugins/tpm ]; then
    echo "==> Cloning tmux plugin manager (tpm)"
    git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

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

# The GlassPill Quickshell bar (dotfiles/quickshell/) retired 2026-08-14:
# the Omarchy 4 shell bar took over as the main bar (pill-styled via the
# raymond.bar plugin, symlinked with the other omarchy plugins below). The
# quickshell/ dir stays in the repo as pre-Quattro reference only, so no
# ~/.config/quickshell symlink is created anymore.

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

# herdr config. Per-file (not dir-level) because ~/.config/herdr/ also holds
# runtime state — sockets, logs, session.json — that must stay machine-local.
if [ -d "$DOTFILES_DIR/herdr" ]; then
    echo "==> Symlinking herdr config"
    mkdir -p ~/.config/herdr
    for src in "$DOTFILES_DIR"/herdr/*; do
        [ -e "$src" ] || continue
        name="$(basename "$src")"
        dst="$HOME/.config/herdr/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            mv "$dst" "$dst.bak.$(date +%s)"
            echo "Backed up $dst"
        fi
        ln -sfn "$src" "$dst"
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

echo "==> Registering custom MIME types (text/x-org)"
mkdir -p ~/.local/share/mime/packages
ln -sfn "$DOTFILES_DIR/xdg/mime/packages/org.xml" ~/.local/share/mime/packages/org.xml
if command -v update-mime-database &>/dev/null; then
    update-mime-database ~/.local/share/mime &>/dev/null || true
fi

# Per-file symlinks for Omarchy app configs. Per-file (rather than dir-level)
# because we want machine-specific files like ~/.config/hypr/monitors.lua to
# stay locally owned, and we want Omarchy to keep adding new files alongside ours.
# walker/swayosd dropped with Omarchy 4 (Quattro, 2026-08-14): both programs
# are retired upstream, replaced by the omarchy-shell. Their config dirs in
# this repo remain as pre-Quattro reference only.
echo "==> Symlinking Omarchy app configs (hypr)"
for app in hypr; do
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

# The omarchy-shell bar is the main bar (decided 2026-08-14, post-Quattro);
# make sure no stale bar-off toggle from the GlassPill era suppresses it.
mkdir -p ~/.local/state/omarchy/toggles
rm -f ~/.local/state/omarchy/toggles/bar-off

# Raymond's idle policy: display stays on, no auto-lock on idle (locking is
# deliberate via SUPER+CTRL+L; sleep still locks via omarchy-sleep-lock).
# These disable the shell's default screensaver@150s / lock@300s:
# "stay-awake" is the idle kill-switch (omarchy-toggle-idle stay-awake),
# screensaver-off additionally retires the screensaver outright.
mkdir -p ~/.local/state/omarchy/indicators
touch ~/.local/state/omarchy/indicators/stay-awake
touch ~/.local/state/omarchy/toggles/screensaver-off

echo "==> Ensuring per-machine Hyprland override files exist"
# local.lua: per-machine overrides, loaded last by hyprland.lua.
[ -e ~/.config/hypr/local.lua ] || printf '%s\n' \
    "-- Per-machine Hyprland overrides (not tracked in dotfiles)." \
    "-- Loaded last from hyprland.lua, so values here win." \
    > ~/.config/hypr/local.lua
# monitors.lua: machine-local monitor config; seed a 1x default.
[ -e ~/.config/hypr/monitors.lua ] || printf '%s\n' \
    "-- Machine-local monitor config (not tracked in dotfiles)." \
    'hl.env("GDK_SCALE", "1")' \
    'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' \
    > ~/.config/hypr/monitors.lua

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

if [ "$OS" = "Linux" ] && [ -d "$DOTFILES_DIR/keyd" ] && command -v keyd >/dev/null 2>&1; then
    # keyd config: copy (not symlink) into /etc/keyd/, same reasoning as the
    # systemd units below -- the root daemon starts before /home is guaranteed,
    # so it must not depend on a symlink into the home tree. The dotfile is
    # authoritative; re-run install.sh (or `sudo keyd reload`) after editing.
    echo "==> Installing keyd config and enabling the service"
    for src in "$DOTFILES_DIR"/keyd/*.conf; do
        [ -e "$src" ] || continue
        sudo install -Dm644 "$src" "/etc/keyd/$(basename "$src")"
    done
    sudo systemctl enable --now keyd 2>/dev/null || true
    sudo keyd reload 2>/dev/null || true
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
    # Keep the per-user systemd manager (user@UID.service) alive across full
    # logout and running from boot. Without this, tmux's systemd-run scope
    # (tmux-server.scope, under user@.service) — and the user units installed
    # above — are torn down when the last session ends. Marker lives at
    # /var/lib/systemd/linger/$USER, so it's machine-local state, not a dotfile.
    if ! loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
        echo "==> Enabling linger for $USER (tmux/user units survive logout)"
        loginctl enable-linger "$USER" 2>/dev/null || true
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
    # wallpaper is a video (e.g. mornye's mp4 wallpaper). Without it the
    # hook silently fails and the wallpaper layer goes blank.
    if command -v yay &>/dev/null && ! pacman -Q mpvpaper &>/dev/null; then
        echo "==> Installing mpvpaper from AUR"
        yay -S --noconfirm mpvpaper
    fi
    # Daily-driver apps that live in the AUR: Zotero (research library),
    # rencal (calendar TUI), Beeper (all non-academic messaging -- unified
    # chat, incl. self-hosted iMessage via a bbctl bridge that runs on the
    # Mac). Personal task tracking is org-agenda only; basilk was removed
    # 2026-08-04.
    if command -v yay &>/dev/null && ! pacman -Q zotero-bin &>/dev/null; then
        echo "==> Installing Zotero from AUR"
        yay -S --noconfirm zotero-bin
    fi
    if command -v yay &>/dev/null && ! pacman -Q rencal-bin &>/dev/null; then
        echo "==> Installing rencal from AUR"
        yay -S --noconfirm rencal-bin
    fi
    if command -v yay &>/dev/null && ! pacman -Q beeper-bin &>/dev/null; then
        echo "==> Installing Beeper from AUR"
        yay -S --noconfirm beeper-bin
    fi
    # herdr: agent-aware terminal multiplexer, evaluated as firstmate's
    # pane backend and a standalone tool. The pi coding agent itself is
    # Omarchy-provided (install/packaging/npx.sh), so it needs no install
    # here; only its packages (pi-rlm) and config are dotfiles-tracked.
    if command -v yay &>/dev/null && ! pacman -Q herdr-bin &>/dev/null; then
        echo "==> Installing herdr from AUR"
        yay -S --noconfirm herdr-bin
    fi
    # beads (bd): dependency-graph issue tracker and persistent memory for
    # coding agents. Agent-facing only -- personal tasks stay in org-agenda.
    # Each repo gets its own .beads/ database; databases stay local (no
    # `bd dolt push`), so no cross-machine schema skew to manage. Only the
    # binary is dotfiles-tracked. Never run `bd init` in research-public.
    if command -v yay &>/dev/null && ! pacman -Q beads-bin &>/dev/null; then
        echo "==> Installing beads from AUR"
        yay -S --noconfirm beads-bin
    fi
    # firefox-pwa hosts the PWAs whose upstreams publish a manifest and
    # don't block non-Chromium browsers, so external links open in the
    # default browser (LibreWolf) instead of being trapped in a Chromium
    # app window. The launchers, and the pwa-setup script that registers
    # them, live in the private overlay (run at the end of this script).
    if command -v yay &>/dev/null && ! pacman -Q firefox-pwa &>/dev/null; then
        echo "==> Installing firefox-pwa from AUR"
        yay -S --noconfirm firefox-pwa
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

echo "==> Symlinking custom Omarchy hooks, themes, themed, extensions, and plugins"
# Full rm-then-recreate of each managed subdir's symlinks so themes/hooks
# removed from the repo (e.g. blue-girl→mornye rename, philosophy deletion)
# don't leave dangling symlinks that omarchy-theme-set enumerates as
# valid options. Any regular file at the destination gets moved to
# .bak.<epoch> first (defensive — should never happen but guards against
# hand-created files in these managed dirs).
for sub in hooks themes themed extensions plugins; do
    src_dir="$DOTFILES_DIR/omarchy/$sub"
    dst_dir="$HOME/.config/omarchy/$sub"
    [ -d "$src_dir" ] || continue
    mkdir -p "$dst_dir"
    # Move any non-symlink entries out of the way; then rm all symlinks.
    for entry in "$dst_dir"/*; do
        [ -e "$entry" ] || continue
        if [ -L "$entry" ]; then
            rm "$entry"
        else
            mv "$entry" "$entry.bak.$(date +%s)"
        fi
    done
    # Recreate symlinks from the source dir.
    for src in "$src_dir"/*; do
        [ -e "$src" ] || continue
        ln -sfn "$src" "$dst_dir/$(basename "$src")"
    done
done

echo "==> Installing omarchy shell config (bar layout, font size)"
# COPIES, not symlinks: omarchy-shell-config (and the shell settings UI)
# rewrites shell.json via tmp-file + mv, which would replace a symlink with
# a plain file on the first edit. So the tracked copy is installed over the
# stock default; edits made live on a machine must be copied back
# (cp ~/.config/omarchy/shell.{json,toml} "$DOTFILES_DIR"/omarchy/) and
# committed, or a re-run of this script reverts them (after a .bak).
for f in shell.json shell.toml; do
    src="$DOTFILES_DIR/omarchy/$f"
    dst="$HOME/.config/omarchy/$f"
    [ -e "$src" ] || continue
    if ! cmp -s "$src" "$dst"; then
        [ -e "$dst" ] && mv "$dst" "$dst.bak.$(date +%s)"
        cp -p "$src" "$dst"
    fi
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

# Sweep up after ourselves. Runs LAST, so every link this script installs
# has already been (re)created: whatever is still broken and still points
# into this repo is genuinely an orphan of a rename or a deletion.
# ~/.config is swept one level deep, which covers both the whole-directory
# links (~/.config/nvim and friends) and the per-file ones, without this
# list having to track every destination the loops above compute.
echo "==> Pruning orphaned symlinks from earlier layouts"
BEFORE_USER_UNITS=0
prune_orphan_links "$HOME/.config" "$DOTFILES_DIR"
for d in "$HOME"/.config/*/; do
    prune_orphan_links "${d%/}" "$DOTFILES_DIR"
done
BEFORE_USER_UNITS=$PRUNED_COUNT
prune_orphan_links "$HOME/.config/systemd/user" "$DOTFILES_DIR"
USER_UNITS_PRUNED=$((PRUNED_COUNT - BEFORE_USER_UNITS))
prune_orphan_links "$HOME/.local/bin" "$DOTFILES_DIR"
prune_orphan_links "$HOME/.local/share/applications" "$DOTFILES_DIR"
for d in /etc/udev/rules.d /etc/keyd /etc/systemd/system \
         /etc/systemd/system-sleep /etc/pacman.d/hooks; do
    prune_orphan_links "$d" "$DOTFILES_DIR" sudo
done
# A removed unit link leaves systemd holding the old view until it re-reads.
if [ "$USER_UNITS_PRUNED" -gt 0 ] && command -v systemctl >/dev/null; then
    systemctl --user daemon-reload || true
fi
if [ "$PRUNED_COUNT" -eq 0 ]; then
    echo "    nothing to prune"
fi

# Private overlay: a sibling repo (not public) carries config that
# follows me to new machines but stays off the public side. Optional —
# everything above works without it.
if [ -x "$HOME/code/dotfiles-private/install.sh" ]; then
    echo "==> Running private-overlay installer"
    "$HOME/code/dotfiles-private/install.sh"
fi

echo "==> Done. Launch nvim to finish plugin install."
echo "==> Remaining manual steps:"
echo "    1. Run 'gh auth login' to authenticate GitHub CLI"
echo "    2. Set up Zotero and the Better BibTeX (BBT) extension"

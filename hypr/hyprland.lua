-- Omarchy 4 (Quattro) entry point. Hyprland loads this instead of
-- hyprland.conf; the old .conf files stay in the repo as the pre-Quattro
-- reference until the port has soaked.

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Drop the preinstalled app/webapp bindings (HEY, X, WhatsApp, Herdr,
-- Omawrite, Spotify, ...). Several target programs deliberately not
-- installed on this machine; the keys they'd occupy are rebound below.
-- Core window-manager bindings stay on.
omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Personal overrides, loaded after the defaults so they win.
-- monitors.lua and local.lua are machine-local plain files in
-- ~/.config/hypr (seeded by install.sh); the rest are dotfiles symlinks.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.windows")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Default browser for keybind-launched GUI apps that consult $BROWSER
-- (shell rc-additions.sh sets the same for terminal-launched apps).
hl.env("BROWSER", "librewolf")

-- Route omarchy-capture-screenshot into a Screenshots/ subdir under
-- Pictures, freeing the parent for other images. Same dual-set pattern
-- as BROWSER above — shell rc-additions.sh mirrors this for terminal-
-- launched invocations.
hl.env("OMARCHY_SCREENSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")

-- TeX personal package tree lives in dotfiles (dotfiles/texmf/) instead
-- of the default ~/texmf/. Dual-set with rc-additions.sh so both keybind-
-- launched and terminal-launched LaTeX tooling see it.
hl.env("TEXMFHOME", os.getenv("HOME") .. "/code/dotfiles/texmf")

-- Per-machine overrides (not tracked in dotfiles; created by install.sh).
-- Loaded last so values here win.
pcall(require, "hypr.local")

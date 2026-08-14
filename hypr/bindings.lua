-- Personal keybindings. Loaded after Omarchy's defaults; unbind a default
-- before rebinding its key (duplicate binds both fire).
-- Port of the pre-Quattro bindings.conf.

-- Application bindings ------------------------------------------------------

-- Terminal: tmux session by default, plain terminal on CTRL.
-- (SUPER+CTRL+RETURN was Herdr, gone with omarchy_preinstalled_bindings=false.)
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Tmux", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" ~/.config/hypr/scripts/tmux-launch.sh')
o.bind("SUPER + CTRL + RETURN", "Terminal", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"')

-- Browser: Omarchy's own SUPER+SHIFT+RETURN / SUPER+SHIFT+B /
-- SUPER+SHIFT+ALT+B defaults already do exactly what the old config
-- restated, so they are left alone.

-- Music/Scribbles special workspaces (scripts auto-populate when empty).
-- SUPER+SHIFT+N is "Editor" in the Quattro essentials — unbind first.
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + M", "Music (toggle special:music; auto-launch if empty)", "~/.config/hypr/scripts/music.sh")
o.bind("SUPER + SHIFT + N", "Scribbles (toggle special:notes; auto-yazi if empty)", "~/.config/hypr/scripts/scribbles.sh")

-- File manager: yazi. Nautilus is not installed on this machine, so its
-- default binds would be dead — unbind them.
hl.unbind("SUPER + SHIFT + F")
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + E", "File manager (yazi)", "uwsm-app -- kitty --class yazi -e yazi")

o.bind("SUPER + SHIFT + O", "Notes", { launch = "obsidian", focus = "^obsidian$" })

-- vim-style window navigation (replaces SUPER+arrow defaults) ---------------
-- SUPER+J (togglesplit), SUPER+K (keybindings viewer — still reachable via
-- the SUPER+R menu), and SUPER+L (workspace layout toggle) are defaults that
-- collide with HJKL navigation.
hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
hl.unbind("SUPER + SHIFT + LEFT")
hl.unbind("SUPER + SHIFT + RIGHT")
hl.unbind("SUPER + SHIFT + UP")
hl.unbind("SUPER + SHIFT + DOWN")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

o.bind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))

o.bind("SUPER + SHIFT + H", "Swap window left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window right", hl.dsp.window.swap({ direction = "r" }))

-- SUPER+T toggles float/tile (omarchy default); SHIFT+T flips split direction
-- (the default togglesplit key SUPER+J is taken by focus-down above).
o.bind("SUPER + SHIFT + T", "Toggle split direction", hl.dsp.layout("togglesplit"))

-- Menus ---------------------------------------------------------------------
-- ESC is Emacs's back key; the system menu must not sit on SUPER+ESCAPE.
-- SUPER+R keeps the root menu for muscle memory (SUPER+SPACE also works).
hl.unbind("SUPER + ESCAPE")
hl.unbind("SUPER + SHIFT + code:201")
o.bind("SUPER + R", "Omarchy menu", "omarchy-menu toggle")

-- SUPER+SHIFT+SPACE toggles the omarchy-shell bar, which is deliberately
-- kept off (the GlassPill Quickshell bar replaces it). Unbind so a stray
-- chord can't resurrect it; re-enable via `omarchy toggle bar` if wanted.
hl.unbind("SUPER + SHIFT + SPACE")

-- Dead defaults: herdr and omacalc are not installed on this machine
-- (removed with the rest of the unwanted Quattro default apps).
hl.unbind("SUPER + CTRL + K")
hl.unbind("SUPER + CTRL + Q")
hl.unbind("XF86Calculator")

-- Calendar — launches rencal (AUR: rencal-bin). The default SUPER+SHIFT+C
-- HEY-webapp went away with omarchy_preinstalled_bindings=false. SUPER+C
-- (Universal copy) and SUPER+CTRL+C (capture menu) are untouched — SUPER+C
-- is load-bearing for image paste into the Claude CLI.
o.bind("SUPER + SHIFT + C", "Calendar", "uwsm-app -- rencal")

-- Display scale: cycle through known-good Hyprland scales (1.0 → 2.0 in 0.25
-- steps). Bridges the laptop/dock transition — bump up on the high-DPI
-- laptop panel, bump down on the dock's external monitor. Applies to every
-- enabled monitor at once. (Omarchy's own SUPER+SLASH scaling is per-monitor
-- and stays available.)
o.bind("SUPER + ALT + equal", "Display scale up", "~/.config/hypr/scripts/scale.sh up")
o.bind("SUPER + ALT + minus", "Display scale down", "~/.config/hypr/scripts/scale.sh down")

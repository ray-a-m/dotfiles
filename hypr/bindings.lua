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

-- Music special workspace (the script auto-populates it when empty).
o.bind("SUPER + SHIFT + M", "Music (toggle special:music; auto-launch if empty)", "~/.config/hypr/scripts/music.sh")

-- File manager: yazi. Nautilus is not installed on this machine, so its
-- default binds would be dead — unbind them.
hl.unbind("SUPER + SHIFT + F")
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + E", "File manager (yazi)", "uwsm-app -- kitty --class yazi -e yazi")

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
-- SUPER+R keeps the root menu for muscle memory. SUPER+SPACE opens the app
-- launcher directly, as walker did pre-Quattro (the Quattro default put the
-- root menu there instead).
hl.unbind("SUPER + ESCAPE")
hl.unbind("SUPER + SHIFT + code:201")
hl.unbind("SUPER + SPACE")
o.bind("SUPER + R", "Omarchy menu", "omarchy-menu toggle")
o.bind("SUPER + SPACE", "App launcher", "omarchy-menu toggle apps")

-- The power button goes to the rebuilt System menu ("power" in the menu
-- jsonc), which confirms Restart/Shutdown and omits Logout. The stock
-- default routes to the stock system submenu, which has neither guard.
hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle power", { locked = true })

-- SUPER+SHIFT+SPACE toggles the omarchy-shell bar off. The bar is now the
-- main bar (pill-styled clone), so keep the toggle unbound to protect it
-- from a stray chord; `omarchy-bar` still toggles it when wanted.
hl.unbind("SUPER + SHIFT + SPACE")

-- herdr is installed (reinstated post-Quattro), but keeps its pre-Quattro
-- workflow: launched by hand in a bare terminal, driven by its own
-- alt+space prefix (herdr/config.toml) — no Hyprland binds. So the Quattro
-- defaults stay unbound: SUPER+CTRL+K (herdr keybindings menu), and
-- SUPER+CTRL+RETURN is rebound to a plain terminal above. omacalc is not
-- installed; its default is dead too.
hl.unbind("SUPER + CTRL + K")
hl.unbind("SUPER + CTRL + Q")
hl.unbind("XF86Calculator")

-- Calendar — toggles the calendar popout on the Omarchy bar. The widget is
-- the io.github.guiestrela.omarchy-google-calendar-clock plugin, which
-- replaces omarchy.clock and shows Google Calendar events in the popout.
-- The bind speaks to the running shell over IPC, so nothing opens as a
-- window; it replaced rencal (a calendar TUI in a tiling client) on
-- 2026-08-29. The default SUPER+SHIFT+C HEY-webapp went away with
-- omarchy_preinstalled_bindings=false. SUPER+C (Universal copy) and
-- SUPER+CTRL+C (capture menu) are untouched — SUPER+C is load-bearing for
-- image paste into the Claude CLI.
o.bind("SUPER + SHIFT + C", "Calendar",
       "omarchy-shell io.github.guiestrela.omarchy-google-calendar-clock toggle")

-- Display scale: cycle through known-good Hyprland scales (1.0 → 2.0 in 0.25
-- steps). Bridges the laptop/dock transition — bump up on the high-DPI
-- laptop panel, bump down on the dock's external monitor. Applies to every
-- enabled monitor at once. (Omarchy's own SUPER+SLASH scaling is per-monitor
-- and stays available.)
o.bind("SUPER + ALT + equal", "Display scale up", "~/.config/hypr/scripts/scale.sh up")
o.bind("SUPER + ALT + minus", "Display scale down", "~/.config/hypr/scripts/scale.sh down")

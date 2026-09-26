-- Extra autostart processes. Port of the pre-Quattro autostart.conf.
-- Omarchy's own autostart (shell, monitor-watch, udiskie) runs from the
-- defaults; these run in addition.

-- Anchor each session on the home workspace (middle of the 3×3 grid).
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = "5" }))
end)

-- Bar: the omarchy-shell bar (decided 2026-08-14; GlassPill retired with
-- Quattro). Customizations live in the shell config, not here.

-- Video wallpaper: the omarchy-shell background plugin renders images only.
-- The theme-set hook spawns mpvpaper when the theme's wallpaper is a video
-- (and the shell's static background stays underneath as fallback art).
-- Re-run it after login so video backgrounds come up without a theme switch.
o.exec_on_start("sleep 2 && omarchy-hook theme-set")

-- Special-workspace inhabitant. Spawned at session start; the windows.lua
-- rule (matched by --class) places it on special:music silently and snaps
-- it back if ever moved. Spotify (the regular desktop client, since the
-- TUI was dropped 2026-09-25) is NOT autostarted: music.sh launches it
-- into the same workspace on demand.
o.launch_on_start("kitty --class cmus -e cmus")

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
o.exec_on_start("sleep 2 && ~/.config/omarchy/hooks/theme-set")

-- Special-workspace inhabitants. Spawned at session start; the windows.lua
-- rules (matched by --class) place them on special:music silently and snap
-- them back if ever moved.
o.launch_on_start("kitty --class spotify-player -e spotify_player")
o.launch_on_start("kitty --class cmus -e cmus")

-- Scribbles (special:notes) is NOT pre-populated at session start. The bind
-- in bindings.lua calls hypr/scripts/scribbles.sh, which auto-launches yazi
-- rooted at ~/Dropbox/scribbles/ when the workspace is empty.

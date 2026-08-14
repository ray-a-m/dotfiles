-- Extra autostart processes. Port of the pre-Quattro autostart.conf.
-- Omarchy's own autostart (shell, monitor-watch, udiskie) runs from the
-- defaults; these run in addition.

-- Anchor each session on the home workspace (middle of the 3×3 grid).
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.focus({ workspace = "5" }))
end)

-- GlassPill Quickshell bar (dotfiles/quickshell). The omarchy-shell stays
-- running for lock/notifications/OSD/launcher but its bar is suppressed via
-- ~/.local/state/omarchy/toggles/bar-off (created by install.sh). -d
-- detaches; -n exits if an instance with the same config is already
-- running, so a session-reload re-exec no-ops instead of stacking panels.
-- (Distinct config path from omarchy-shell's `-p $OMARCHY_PATH/shell`, so
-- the two instances coexist.)
o.exec_on_start(o.launch("quickshell -d -n"))

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

-- Look'n'feel overrides. Loaded after Omarchy's defaults. Port of the
-- pre-Quattro looknfeel.conf (plus the cursor block that lived in
-- local.conf — it's taste, not hardware, so it's tracked now).

hl.config({
  general = {
    -- The omarchy-shell bar reserves its own strip (exclusive zone), so the
    -- top gap matches the other sides.
    gaps_out = 10,

    -- Border thickness — Hyprland doesn't expose per-focus sizes, so this
    -- is global. With the active border at alpha 0, the size only affects
    -- the *visible* (inactive) line — focused windows get 2 px of
    -- transparent wallpaper-showthrough between content and gap, which
    -- reads as a clean thin edge, and inactive windows get a 2 px black
    -- band that pairs with the inactive shadow (decoration block) into a
    -- noticeable but not overbearing frame.
    border_size = 2,

    col = {
      -- Active: fully transparent — the focused window appears unbordered.
      -- Inactive: solid black, ~2 px thick (see border_size above).
      active_border = "rgba(00000000)",
      inactive_border = "rgba(000000ff)",
    },
  },

  -- Mirror onto window groups (tabbed/stacked) so a grouped window's bar
  -- uses the same palette instead of falling back to omarchy defaults.
  group = {
    col = {
      border_active = "rgba(00000000)",
      border_inactive = "rgba(000000ff)",
    },
  },

  decoration = {
    rounding = 12,

    blur = {
      enabled = true,
      size = 4,
      passes = 3,
      -- Omarchy default brightness=0.60/contrast=0.75 dims the blur for
      -- dark themes; force neutral so light themes keep their wallpaper
      -- vibrancy.
      brightness = 1.0,
      contrast = 1.0,
      -- Required for blur to apply through translucent windows, not just
      -- fully-transparent layer shells.
      ignore_opacity = true,
      new_optimizations = true,
      -- Omarchy 3.8 shipped this on and Quattro's default dropped it.
      -- Without it, special-workspace windows skip blur entirely, so the
      -- 0.65-alpha music kitties read as glassless (far more transparent
      -- than pre-Quattro).
      special = true,
    },

    -- Shadow split between active and inactive so the focus state is
    -- actually distinguishable. Without `color_inactive`, both states
    -- share `color` and shadow halos make focused/unfocused look
    -- identical — defeating the transparent active_border setup above.
    -- Active: fully transparent (no shadow → focused window reads as
    -- truly chromeless). Inactive: solid black, slight offset so it
    -- pairs with the 2 px black border into a single ~4 px frame.
    shadow = {
      enabled = true,
      color = "rgba(00000000)",
      color_inactive = "rgba(000000ff)",
      range = 2,
      render_power = 2,
      offset = "0 0",
    },
  },

  -- Cursor smoothing. Omarchy's default warp_on_change_workspace = 1
  -- teleports the cursor on every workspace switch and on layer-surface
  -- open/close, painting a brief flash. Disable warps and add a 1s
  -- inactive timeout so the cursor self-hides between mouse movements.
  cursor = {
    warp_on_change_workspace = 0,
    inactive_timeout = 1,
  },
})

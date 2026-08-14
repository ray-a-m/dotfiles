-- Window and layer rules. Loaded after Omarchy's defaults, so rules here
-- override or extend them. Port of the pre-Quattro windows.conf.

-- Pin special-workspace inhabitants to their workspaces. The kitty --class
-- tags in autostart.lua make these rules target the right windows (and
-- pull them back if ever moved).
o.window("^spotify-player$", { workspace = "special:music silent" })
o.window("^cmus$", { workspace = "special:music silent" })
o.window("^notes$", { workspace = "special:notes" })

-- GlassPill Quickshell bar surfaces — compositor blur via namespace prefix.
-- Without ignore_alpha, blur applies to every pixel of the (rectangular)
-- layer surface — including the fully-transparent pixels in the corners of
-- a rounded-rectangle GlassPill. Those corners show blurred wallpaper,
-- reading as visible square halos around the pill's rounded edges. 0.1 is
-- below the pill's tintAlpha (0.22) but above the transparent corners
-- (alpha 0) — so the pill blurs as before and the corners go untouched.
hl.layer_rule({ match = { namespace = "^(quickshell-).*" }, blur = true, ignore_alpha = 0.1 })

-- Opacity tiers (last-match-wins). Omarchy tags every window with
-- `default-opacity` and strips it for apps that opt out (terminals via the
-- `terminal` tag, browsers, video, qemu, steam). Active and inactive
-- values held equal — focus state is read from the border color, not from
-- a brightness shift, so the bg should stay still as focus moves.
o.window({ tag = "default-opacity" }, { opacity = "0.90 0.90" })
o.window({ tag = "terminal" }, { opacity = "0.85 0.85" })

-- Reading surfaces — force opaque. Add other PDF readers/image viewers
-- here as they come up.
o.window("^([Zz]otero)$", { tag = "-default-opacity" })
o.window("^([Zz]otero)$", { opacity = "1.0 1.0" })

-- Emacs: fullscreen keeps the WINDOWED look. Omarchy's default gives every
-- window a translucent opacity but fullscreen snaps to 1.0, so Super+F
-- visibly "brightens" the page. `override` = absolute values (plain
-- opacity rules MULTIPLY when stacked with the default tag rule).
-- Active/inactive exactly the default's effective values; fullscreen =
-- active.
o.window("^emacs$", { opacity = "0.95 override 0.9 override 0.95 override" })

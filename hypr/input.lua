-- Input overrides. Loaded after Omarchy's defaults; hl.config merges deep,
-- later values win. Port of the pre-Quattro input.conf.

hl.config({
  input = {
    kb_layout = "us",

    -- No global caps/ctrl remap. The laptop keyboard is remapped by keyd
    -- (dotfiles/keyd/default.conf); the Corne is configured in Vial. The
    -- empty value overrides omarchy's default
    -- "compose:caps,shift:both_capslock_cancel" — caps stays caps here.
    kb_options = "",

    repeat_rate = 40,
    repeat_delay = 250,

    numlock_by_default = true,

    -- Turn off mouse acceleration (default: adaptive).
    accel_profile = "flat",

    touchpad = {
      natural_scroll = true,

      -- Two-finger clicks for right-click instead of lower-right corner.
      clickfinger_behavior = true,

      -- scroll_factor is set per-machine in ~/.config/hypr/local.lua
      -- (touchpad sensitivity varies enough between trackpads to not pin
      -- it here).
    },
  },
})

-- The internal laptop keyboard's remaps (caps->alt, right-alt->ctrl, and the
-- left-Alt/left-Super bottom-row swap) live in keyd — dotfiles/keyd/ —
-- because caps->alt and ralt->ctrl aren't expressible in XKB. keyd grabs the
-- device, so a hypr per-device block keyed on its name would no longer match.

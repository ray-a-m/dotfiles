# ThinkPad Boot Screen for Omarchy

A ThinkPad Plymouth boot screen that integrates natively with [Omarchy](https://omarchy.org/)'s Style → Unlock menu.

![Preview](preview-unlock.png)

## Installation

```bash
git clone https://github.com/Yilmaz41/Thinkpad-boot-screen ~/.config/omarchy/themes/thinkpad
```

Then open the Omarchy menu → **Style → Unlock** and select **Thinkpad**. That's it — Omarchy handles the Plymouth config, SDDM login screen, and initramfs rebuild automatically.

## What's included

| File | Purpose |
|------|---------|
| `unlock.png` | Logo shown during boot (800×188 px) |
| `preview-unlock.png` | Thumbnail shown in the Unlock menu |
| `colors.toml` | Black background (`#000000`), white text (`#ffffff`) |

## Credits

Logo image sourced from [roadkell/ascii-logos](https://github.com/roadkell/ascii-logos) — a fantastic collection of ASCII/Unicode art logos for terminal and boot screens. Big thanks to roadkell for making these available to the community.

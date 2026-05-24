// Quickshell entry point. ShellRoot owns every panel in the philosophy
// shell. Each child is a self-contained PanelWindow with its own layer
// namespace, palette loader, and (where appropriate) GlassPill chrome.
//
// Hyprland blur is applied via two layerrules in hypr/windows.conf,
// both keyed on namespace prefix `^(quickshell-).*`:
//   - `blur` enables the effect
//   - `ignore_alpha 0.1` skips fully-transparent corner pixels so
//      rounded pills don't show square halos
// New panels inherit both rules for free as long as they set
// WlrLayershell.namespace = "quickshell-<name>".
//
// Current panels:
//   - Workspaces: top-left 3×3 numpad grid (no pill chrome)
//   - Clock:      top-center date/time + omarchy update indicator
//   - TrayButton: top-right collapsible cog → expanded status row
//
// The hello-world `quickshell` badge from earlier sessions is retired;
// git history has it if a reference is needed.

import Quickshell

ShellRoot {
    Workspaces {}
    Clock {}
    TrayButton {}
}

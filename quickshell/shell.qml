// Quickshell entry point. ShellRoot owns every panel in the top bar.
// Each child is a self-contained PanelWindow with its own layer
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
//   - Calendar:   popout below the clock pill, toggled by left-clicking
//                 the date text or by SUPER+SHIFT+C via IpcHandler. Hidden
//                 by default.
//   - TrayButton: top-right collapsible cog → expanded status row
//
// Cross-panel state: ShellRoot owns `calendarOpen`. Clock emits
// `dateLeftClicked()` on left-click; the handler here toggles the
// property, and Calendar binds its `open` to it. Keeps each panel
// file decoupled — Clock doesn't need to know Calendar exists, and
// Calendar doesn't need to know what triggers it.
//
// IPC: `qs ipc call calendar toggle` flips the same property, so a
// Hyprland keybind can open/close the calendar without going through
// the Clock pill. See hypr/bindings.conf for the SUPER+SHIFT+C wiring.

import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    property bool calendarOpen: false

    IpcHandler {
        target: "calendar"
        function toggle(): void { shell.calendarOpen = !shell.calendarOpen }
        function open(): void { shell.calendarOpen = true }
        function close(): void { shell.calendarOpen = false }
    }

    Workspaces {}
    Clock {
        onDateLeftClicked: shell.calendarOpen = !shell.calendarOpen
    }
    Calendar {
        open: shell.calendarOpen
    }
    TrayButton {}
}

// Quickshell entry point. For now: a single bottom-left glass-pill badge
// showing "quickshell" — the same hello-world from before, but now
// composed from the palette and glass-pill primitives so it actually
// looks like a philosophy-theme element. Future widgets (workspace
// grid, clock, MPRIS, etc.) follow the same Palette + GlassPill pattern.
//
// Hyprland blurs this surface via `layerrule = blur on, match:namespace
// ^(quickshell-).*` in hypr/windows.conf, keyed on the namespace below.
//
// The palette is loaded inline at panel construction (rather than via a
// separate Palette component) so the color properties are populated
// before child bindings evaluate. A future singleton refactor can
// dedupe this once we have multiple panels reading the same file.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: panel
    WlrLayershell.namespace: "quickshell-hello"

    // Palette properties — populated synchronously from colors.toml by
    // the FileView below. Defaults are the current `philosophy` palette
    // so the shell stays sensible even if the file read fails.
    property color paletteAccent: "#4C97D7"
    property color paletteBackground: "#24180C"
    property color paletteForeground: "#F0D29F"

    FileView {
        id: paletteFile
        path: (Quickshell.env("HOME") || "") + "/.config/omarchy/current/theme/colors.toml"
        preload: true
        blockLoading: true
        printErrors: true
        Component.onCompleted: {
            const text = paletteFile.text()
            if (!text) return
            const re = /^\s*([a-zA-Z0-9_]+)\s*=\s*"(#?[0-9a-fA-F]{6,8})"\s*$/
            const keyToProp = {
                "accent": "paletteAccent",
                "background": "paletteBackground",
                "foreground": "paletteForeground",
            }
            for (const line of text.split("\n")) {
                const m = re.exec(line)
                if (!m) continue
                const prop = keyToProp[m[1]]
                if (!prop) continue
                const value = m[2].startsWith("#") ? m[2] : "#" + m[2]
                panel[prop] = value
            }
        }
    }

    anchors {
        bottom: true
        left: true
    }
    margins.bottom: 8
    margins.left: 8
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    GlassPill {
        id: pill
        anchors.fill: parent
        tint: panel.paletteBackground
        borderTint: panel.paletteForeground
        implicitWidth: label.implicitWidth + 24
        implicitHeight: label.implicitHeight + 12

        Text {
            id: label
            anchors.centerIn: parent
            text: "quickshell"
            color: panel.paletteForeground
            font.family: "monospace"
            font.pixelSize: 13
        }
    }
}

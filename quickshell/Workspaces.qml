// 3×3 numpad-arranged workspace grid. Top-left of the screen, replacing
// the visual role of waybar's hyprland/workspaces module — the cells map
// 1:1 to Raymond's Corne v4.1 numpad layer (KC_1..KC_9, see memory
// hardware_corne.md). Layout matches a physical numpad: top row 7-8-9,
// middle 4-5-6, bottom 1-2-3.
//
// Cell colors:
//   - focused          : accent at 0.85 alpha
//   - exists in model  : background at 0.45 alpha (workspace has windows
//                        OR is active on some monitor — see note below)
//   - otherwise        : background at 0.18 alpha (empty placeholder)
//   - border (all)     : foreground at 0.25 alpha, 1 px
//
// Fills track `paletteBackground` (the terminal's glass tint, e.g.
// catppuccin-latte's near-white `#eff1f5`) so the grid reads as light
// see-through glass over the wallpaper — same surface feel as the
// kitty windows beneath it. Borders use `paletteForeground` for a faint
// dark outline that holds structure even on busy wallpaper patches.
//
// "Exists in model" is the working proxy for "has windows" because
// Hyprland.workspaces only contains workspaces that Hyprland keeps alive
// (those with windows + any currently-active workspace on a monitor).
// An empty-but-focused workspace will read as both focused and exists,
// which is the right visual story anyway.
//
// No GlassPill backing — the 9 cells float directly over the wallpaper
// instead of sitting on a translucent rectangle. The 3×3 arrangement is
// strong enough Gestalt to read as a group without an enclosing chrome.
// Cells touch (rowSpacing=0, columnSpacing=0); the 1 px per-cell border
// supplies the visible grid lines between adjacent cells.
//
// Click → `hyprctl dispatch workspace N`.
//
// Palette is loaded inline per the existing shell.qml convention;
// dedupe to a singleton when a third panel needs it.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: panel
    WlrLayershell.namespace: "quickshell-workspaces"

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
        top: true
        left: true
    }
    margins.top: 8
    // 10 (not 8) so the grid's left edge lines up with the first tiled
    // window's left edge — hyprland's `gaps_out` keeps windows 10px in
    // from the screen edge (see looknfeel.conf).
    margins.left: 10

    readonly property int cellSize: 10

    implicitWidth: cellSize * 3
    implicitHeight: cellSize * 3
    color: "transparent"
    exclusiveZone: 0

    Grid {
        anchors.fill: parent
        rows: 3
        columns: 3
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: [7, 8, 9, 4, 5, 6, 1, 2, 3]
            delegate: Rectangle {
                id: cell
                required property int modelData
                readonly property int wsId: modelData

                readonly property var ws: {
                    const all = Hyprland.workspaces.values
                    for (let i = 0; i < all.length; i++) {
                        if (all[i].id === wsId) return all[i]
                    }
                    return null
                }
                readonly property bool isFocused: ws !== null && ws.focused
                readonly property bool exists: ws !== null

                width: panel.cellSize
                height: panel.cellSize
                radius: 0

                // Cell fills track `paletteBackground` (the terminal's glass
                // tint, e.g. catppuccin-latte's near-white `#eff1f5`) so the
                // grid reads as light see-through glass over the wallpaper,
                // matching the kitty surfaces beneath it. Borders use
                // `paletteForeground` for a faint dark outline that holds
                // structure even on busy wallpaper patches.
                color: isFocused
                    ? Qt.rgba(panel.paletteAccent.r, panel.paletteAccent.g, panel.paletteAccent.b, 0.85)
                    : exists
                        ? Qt.rgba(panel.paletteBackground.r, panel.paletteBackground.g, panel.paletteBackground.b, 0.45)
                        : Qt.rgba(panel.paletteBackground.r, panel.paletteBackground.g, panel.paletteBackground.b, 0.18)
                border.color: Qt.rgba(panel.paletteForeground.r, panel.paletteForeground.g, panel.paletteForeground.b, 0.25)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + cell.wsId)
                }
            }
        }
    }
}

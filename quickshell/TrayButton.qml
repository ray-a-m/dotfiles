// Top-right tray pill. Collapsed by default to a single cog glyph;
// clicking the cog expands the pill to reveal bluetooth, wifi, audio,
// cpu (btop), and battery icons. Clicking the cog again — or any
// extra icon — collapses back.
//
// Implementation note: this is a SELF-RESIZING PanelWindow, not a
// separate PopupWindow. The earlier popup version tried to anchor the
// popup at panel.width - popup.width, which on a right-anchored
// 30-px panel with a 170-px popup resolves to ~-140, putting the
// popup offscreen. The expanding-panel pattern sidesteps that: the
// panel is anchored top+right, so as implicitWidth grows the *left*
// edge moves leftward across the screen while the cog stays pinned
// to the right edge.
//
// v4 scope:
//   - Static icons, no live state (battery %, signal, volume).
//     Live state is the next iteration once placement is stable.
//   - SNI system tray still deferred (separate protocol binding).
//
// Glyphs (JetBrainsMono Nerd Font, all in the Font Awesome BMP range
// so a single `\uXXXX` escape suffices — no surrogate pair handling):
//   bluetooth   U+F293 fa-bluetooth-b
//   wifi        U+F1EB fa-wifi
//   audio       U+F028 fa-volume-up
//   cpu         U+F2DB fa-microchip
//   battery     U+F240 fa-battery-full
//   gear        U+F013 fa-cog
//
// Escapes (not literal glyphs) because the source travels through tools
// that strip out non-ASCII control-plane chars; the runtime expansion
// is identical and the font lookup is unchanged.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: panel
    WlrLayershell.namespace: "quickshell-tray-button"

    property color paletteAccent: "#4C97D7"
    property color paletteBackground: "#24180C"
    property color paletteForeground: "#F0D29F"

    property bool expanded: false

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
        right: true
    }
    margins.top: 8
    // 10 (not 8) so the pill's right edge lines up with the rightmost tiled
    // window's right edge — hyprland's `gaps_out` keeps windows 10px in
    // from the screen edge (see looknfeel.conf). Matches Workspaces' left.
    margins.right: 10

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    GlassPill {
        id: pill
        anchors.fill: parent
        tint: panel.paletteBackground
        borderTint: panel.paletteForeground

        readonly property int iconCell: 18
        readonly property int iconGap: 12
        readonly property int padX: 12
        readonly property int padY: 6

        implicitWidth: padX * 2 + iconRow.implicitWidth
        implicitHeight: padY * 2 + iconCell

        Row {
            id: iconRow
            anchors.right: parent.right
            anchors.rightMargin: pill.padX
            anchors.verticalCenter: parent.verticalCenter
            spacing: pill.iconGap

            // Extras appear to the left of the cog when `expanded` is true.
            // The Repeater drives off an empty list when collapsed, so the
            // Row's implicit width drops to just the cog cell — which is
            // what lets the panel collapse cleanly.
            Repeater {
                model: panel.expanded ? [
                    { glyph: "", cmd: "omarchy-launch-bluetooth" },
                    { glyph: "", cmd: "omarchy-launch-wifi" },
                    { glyph: "", cmd: "omarchy-launch-audio" },
                    { glyph: "", cmd: "omarchy-launch-or-focus-tui btop" },
                    { glyph: "", cmd: "omarchy-menu power" },
                ] : []
                delegate: Item {
                    required property var modelData
                    width: pill.iconCell
                    height: pill.iconCell

                    Text {
                        id: extraLabel
                        anchors.centerIn: parent
                        text: modelData.glyph
                        color: panel.paletteForeground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: extraLabel.color = panel.paletteAccent
                        onExited: extraLabel.color = panel.paletteForeground
                        onClicked: {
                            Hyprland.dispatch("exec, " + modelData.cmd)
                            panel.expanded = false
                        }
                    }
                }
            }

            // Cog: always present, toggles expansion. Stays pinned to the
            // pill's right edge regardless of expanded state.
            Item {
                width: pill.iconCell
                height: pill.iconCell

                Text {
                    id: cogLabel
                    anchors.centerIn: parent
                    text: ""
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: cogLabel.color = panel.paletteAccent
                    onExited: cogLabel.color = panel.paletteForeground
                    onClicked: panel.expanded = !panel.expanded
                }
            }
        }
    }
}

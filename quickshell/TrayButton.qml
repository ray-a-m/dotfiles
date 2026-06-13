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
//   - Most icons stay static (signal, volume) — wire up live state as
//     each one gets requested.
//   - Battery has live state: glyph tracks discharge bracket / switches
//     to bolt while charging; an inline "NN%" label sits next to it so
//     the level is readable at a glance without hover or click.
//     Right-click pops a `notify-send` with the full
//     `omarchy-battery-status` line (time to empty, draw, capacity Wh).
//   - SNI system tray still deferred (separate protocol binding).
//
// Glyphs (JetBrainsMono Nerd Font, all in the Font Awesome BMP range):
//   bluetooth   U+F293 fa-bluetooth-b
//   wifi        U+F1EB fa-wifi
//   audio       U+F028 fa-volume-up
//   cpu         U+F2DB fa-microchip
//   battery     U+F240..U+F244 fa-battery-(full|three-quarters|half|quarter|empty)
//   charging    U+F0E7 fa-bolt
//   gear        U+F013 fa-cog
//
// All glyphs go through String.fromCodePoint rather than embedding the
// literal character. Mirrors the Clock.qml convention (its comment
// explains the source-pipeline stripping hazard that bit BMP glyphs
// previously) and means this file is ASCII-clean end to end.

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

    // Live battery state. -1 sentinel = "not yet read"; the glyph falls
    // back to fa-battery-full and the percent label suppresses itself.
    property int batteryPercent: -1
    property bool batteryCharging: false

    // sysfs read avoids a process spawn on the hot path. blockLoading
    // makes reload() synchronous so text() returns the fresh value
    // inside the timer tick. The files are 3-12 bytes each.
    FileView {
        id: batteryCapacityFile
        path: "/sys/class/power_supply/BAT0/capacity"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: batteryStatusFile
        path: "/sys/class/power_supply/BAT0/status"
        blockLoading: true
        printErrors: false
    }
    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            batteryCapacityFile.reload()
            batteryStatusFile.reload()
            const c = batteryCapacityFile.text()
            const s = batteryStatusFile.text()
            if (c) {
                const p = parseInt(c.trim())
                if (!isNaN(p)) panel.batteryPercent = p
            }
            if (s) {
                const t = s.trim().toLowerCase()
                panel.batteryCharging = (t === "charging" || t === "full")
            }
        }
    }

    // Font Awesome battery glyph by current state. Bolt while charging;
    // otherwise a five-bracket discharge scale.
    function batteryGlyph() {
        if (panel.batteryCharging) return String.fromCodePoint(0xF0E7)  // bolt
        const p = panel.batteryPercent
        if (p < 0)   return String.fromCodePoint(0xF240)  // unknown -> full
        if (p >= 88) return String.fromCodePoint(0xF240)  // full
        if (p >= 63) return String.fromCodePoint(0xF241)  // three-quarters
        if (p >= 38) return String.fromCodePoint(0xF242)  // half
        if (p >= 11) return String.fromCodePoint(0xF243)  // quarter
        return String.fromCodePoint(0xF244)               // empty
    }
    function batteryLabel() {
        return panel.batteryPercent >= 0 ? panel.batteryPercent + "%" : ""
    }

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
            //
            // `label` adds an inline text fragment after the glyph
            // (battery uses it for "NN%"); `rclick` is an optional shell
            // command bound to right-click. Empty values are skipped by
            // the delegate.
            Repeater {
                model: panel.expanded ? [
                    { glyph: String.fromCodePoint(0xF293), label: "", cmd: "omarchy-launch-bluetooth", rclick: "" },
                    { glyph: String.fromCodePoint(0xF1EB), label: "", cmd: "omarchy-launch-wifi", rclick: "" },
                    { glyph: String.fromCodePoint(0xF028), label: "", cmd: "omarchy-launch-audio", rclick: "" },
                    { glyph: String.fromCodePoint(0xF2DB), label: "", cmd: "omarchy-launch-or-focus-tui btop", rclick: "" },
                    { glyph: panel.batteryGlyph(), label: panel.batteryLabel(),
                      cmd: "omarchy-menu power",
                      rclick: "notify-send -u low \"$(omarchy-battery-status)\"" },
                ] : []
                delegate: Item {
                    required property var modelData
                    width: extraRow.implicitWidth
                    height: pill.iconCell

                    Row {
                        id: extraRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: extraGlyph
                            text: modelData.glyph
                            color: panel.paletteForeground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: extraLabel
                            visible: modelData.label && modelData.label.length > 0
                            text: modelData.label || ""
                            color: panel.paletteForeground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: { extraGlyph.color = panel.paletteAccent; extraLabel.color = panel.paletteAccent }
                        onExited:  { extraGlyph.color = panel.paletteForeground; extraLabel.color = panel.paletteForeground }
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton && modelData.rclick) {
                                // Right-click stays expanded so the
                                // notification surfaces alongside the
                                // open row; cog collapses.
                                Hyprland.dispatch("exec " + modelData.rclick)
                            } else {
                                Hyprland.dispatch("exec " + modelData.cmd)
                                panel.expanded = false
                            }
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
                    text: String.fromCodePoint(0xF013)
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

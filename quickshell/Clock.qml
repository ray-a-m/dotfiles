// Top-center clock pill — date/time, conditional state indicators
// (screen-recording, idle-disabled, notification-silencing), and the
// omarchy update glyph. All in one centered pill so the top of the
// screen stays uncluttered when nothing is active.
//
// State indicators each poll a lightweight system check every 3 s and
// render only when their condition is true. Color flips to muted red
// (#a55555) on active, matching waybar's old `.active` rule so the
// visual semantics carry over without a theme swap. Clicking an
// indicator runs its toggle command (omarchy-toggle-idle /
// omarchy-toggle-notification-silencing / omarchy-capture-screenrecording).
//
// Time refresh: 60 s — the format only shows minutes. Update poll:
// 6 h, matches the old waybar interval. Indicator poll: 3 s — strikes
// a balance between responsiveness and process spawn cost (three
// pgrep / makoctl invocations per cycle).
//
// MDI glyphs (supplementary plane U+F0xxx) are written via
// String.fromCodePoint to avoid the source-pipeline glyph-stripping that
// bit the early BMP-range glyphs — ASCII source is invulnerable.
// Voxtype was not ported: the binary isn't installed and the indicator
// was already a no-op.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: panel
    WlrLayershell.namespace: "quickshell-clock"

    property color paletteAccent: "#4C97D7"
    property color paletteBackground: "#24180C"
    property color paletteForeground: "#F0D29F"

    // State indicators — true means the condition is active and the
    // glyph should render.
    property bool updateAvailable: false
    property bool screenRecActive: false
    property bool idleDisabled: false
    property bool silencingActive: false

    readonly property color activeColor: "#a55555"

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
    }
    margins.top: 8

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    property string nowString: ""

    function refreshNow() {
        nowString = Qt.formatDateTime(new Date(), "dddd, MMMM d hh:mm AP")
    }

    Component.onCompleted: refreshNow()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: panel.refreshNow()
    }

    // ──────────────── omarchy update poll (6 h) ────────────────
    Process {
        id: updatePoll
        command: ["omarchy-update-available"]
        onExited: (exitCode, exitStatus) => {
            panel.updateAvailable = (exitCode === 0)
        }
    }

    Timer {
        interval: 21600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: updatePoll.running = true
    }

    // ──────────────── state indicators poll (3 s) ───────────────
    // screen-recording: gpu-screen-recorder runs while recording.
    Process {
        id: screenRecPoll
        command: ["pgrep", "-f", "^gpu-screen-recorder"]
        onExited: (code) => panel.screenRecActive = (code === 0)
    }
    // idle-disabled: hypridle running means idle works → no warning.
    // hypridle NOT running means idle disabled → show warning.
    Process {
        id: idlePoll
        command: ["pgrep", "-x", "hypridle"]
        onExited: (code) => panel.idleDisabled = (code !== 0)
    }
    // notification-silencing: makoctl reports current mode; pipe with
    // sh -c because Process.command doesn't shell-parse.
    Process {
        id: silencingPoll
        command: ["sh", "-c", "makoctl mode | grep -q 'do-not-disturb'"]
        onExited: (code) => panel.silencingActive = (code === 0)
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            screenRecPoll.running = true
            idlePoll.running = true
            silencingPoll.running = true
        }
    }

    GlassPill {
        id: pill
        anchors.fill: parent
        tint: panel.paletteBackground
        borderTint: panel.paletteForeground

        readonly property int padX: 9
        readonly property int padY: 3
        readonly property int innerGap: 8

        implicitWidth: padX * 2 + rowContent.implicitWidth
        implicitHeight: padY * 2 + rowContent.implicitHeight

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: pill.innerGap

            Text {
                id: dateText
                text: panel.nowString
                color: panel.paletteForeground
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.RightButton
                    onClicked: Hyprland.dispatch("exec, omarchy-launch-floating-terminal-with-presentation omarchy-tz-select")
                }
            }

            // Screen recording — MDI U+F0EC2 video.
            Text {
                id: screenRecIcon
                visible: panel.screenRecActive
                text: String.fromCodePoint(0xF0EC2)
                color: panel.activeColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("exec, omarchy-capture-screenrecording")
                }
            }

            // Idle disabled — MDI U+F1AD6 moon-off.
            Text {
                id: idleIcon
                visible: panel.idleDisabled
                text: String.fromCodePoint(0xF1AD6)
                color: panel.activeColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("exec, omarchy-toggle-idle")
                }
            }

            // Notification silencing — MDI U+F009B bell-off.
            Text {
                id: silencingIcon
                visible: panel.silencingActive
                text: String.fromCodePoint(0xF009B)
                color: panel.activeColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("exec, omarchy-toggle-notification-silencing")
                }
            }

            // Omarchy update available — U+F021 fa-sync.
            Text {
                id: updateIcon
                visible: panel.updateAvailable
                text: ""
                color: panel.paletteForeground
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: updateIcon.color = panel.paletteAccent
                    onExited: updateIcon.color = panel.paletteForeground
                    onClicked: Hyprland.dispatch("exec, omarchy-launch-floating-terminal-with-presentation omarchy-update")
                }
            }
        }
    }
}

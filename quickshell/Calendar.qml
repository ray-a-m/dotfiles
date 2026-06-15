// Compact monthly calendar popout — toggled by left-clicking the Clock
// pill or via SUPER+SHIFT+C (Hyprland keybind → qs ipc call calendar
// toggle → IpcHandler in shell.qml). Same GlassPill chrome as the rest
// of the bar; sits directly below the clock with matching top-anchor +
// horizontal centering.
//
// Navigation: ‹ / › step month, ⟪ / ⟫ step year. Clicking the
// "Month YYYY" label jumps back to today. The view month resets to
// the current month each time the popup opens so the user always
// lands on "now" after closing and reopening.
//
// State design: each cell's date is derived from `viewDate` (first of
// the displayed month) plus the cell index minus the leading offset
// to the previous Sunday. `todayDate` is refreshed on every open so
// a popup that's been around past midnight highlights the right day.
//
// Future-room: Google Calendar event markers would slot in as a thin
// strip below each day's number, reading from a list indexed by
// (year, month, day). The current cell delegate has the layout
// headroom for it. No wiring committed yet — explicitly opt-in later.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel
    WlrLayershell.namespace: "quickshell-calendar"

    property bool open: false
    property color paletteAccent: "#4C97D7"
    property color paletteBackground: "#24180C"
    property color paletteForeground: "#F0D29F"

    property date viewDate: panel.firstOfMonth(new Date())
    property date todayDate: new Date()

    function firstOfMonth(d) {
        return new Date(d.getFullYear(), d.getMonth(), 1)
    }
    function shiftMonth(delta) {
        const d = panel.viewDate
        panel.viewDate = new Date(d.getFullYear(), d.getMonth() + delta, 1)
    }
    function shiftYear(delta) {
        const d = panel.viewDate
        panel.viewDate = new Date(d.getFullYear() + delta, d.getMonth(), 1)
    }
    function goToday() {
        panel.todayDate = new Date()
        panel.viewDate = panel.firstOfMonth(panel.todayDate)
    }
    function sameYMD(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    onOpenChanged: {
        if (open) panel.goToday()
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

    visible: panel.open
    anchors {
        top: true
    }
    // Clock pill: margins.top 8 + ~22 height + 8 gap ≈ 38.
    margins.top: 38

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    GlassPill {
        id: pill
        anchors.fill: parent
        tint: panel.paletteBackground
        borderTint: panel.paletteForeground

        readonly property int padX: 10
        readonly property int padY: 8
        readonly property int cellWidth: 24
        readonly property int cellHeight: 22
        readonly property int headerGap: 6
        readonly property color dimForeground: Qt.rgba(
            panel.paletteForeground.r,
            panel.paletteForeground.g,
            panel.paletteForeground.b,
            0.35
        )
        readonly property color mutedForeground: Qt.rgba(
            panel.paletteForeground.r,
            panel.paletteForeground.g,
            panel.paletteForeground.b,
            0.6
        )
        readonly property color todayTint: Qt.rgba(
            panel.paletteAccent.r,
            panel.paletteAccent.g,
            panel.paletteAccent.b,
            0.35
        )

        implicitWidth: padX * 2 + content.implicitWidth
        implicitHeight: padY * 2 + content.implicitHeight

        Column {
            id: content
            anchors.centerIn: parent
            spacing: pill.headerGap

            // ──────────────── header row ────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    id: yearPrev
                    text: "⟪"
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    width: 14
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: yearPrev.color = panel.paletteAccent
                        onExited: yearPrev.color = panel.paletteForeground
                        onClicked: panel.shiftYear(-1)
                    }
                }

                Text {
                    id: monthPrev
                    text: "‹"
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    width: 12
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: monthPrev.color = panel.paletteAccent
                        onExited: monthPrev.color = panel.paletteForeground
                        onClicked: panel.shiftMonth(-1)
                    }
                }

                Text {
                    id: monthLabel
                    text: Qt.formatDate(panel.viewDate, "MMMM yyyy")
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    width: pill.cellWidth * 5
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: monthLabel.color = panel.paletteAccent
                        onExited: monthLabel.color = panel.paletteForeground
                        onClicked: panel.goToday()
                    }
                }

                Text {
                    id: monthNext
                    text: "›"
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    width: 12
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: monthNext.color = panel.paletteAccent
                        onExited: monthNext.color = panel.paletteForeground
                        onClicked: panel.shiftMonth(1)
                    }
                }

                Text {
                    id: yearNext
                    text: "⟫"
                    color: panel.paletteForeground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    width: 14
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: yearNext.color = panel.paletteAccent
                        onExited: yearNext.color = panel.paletteForeground
                        onClicked: panel.shiftYear(1)
                    }
                }
            }

            // ──────────────── day-of-week labels ────────────────
            Row {
                spacing: 0
                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    delegate: Text {
                        required property string modelData
                        width: pill.cellWidth
                        height: 14
                        text: modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: pill.mutedForeground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                }
            }

            // ──────────────── day grid (6 weeks × 7 days) ────────────────
            Grid {
                columns: 7
                rows: 6
                spacing: 0
                Repeater {
                    model: 42
                    delegate: Item {
                        id: cell
                        required property int index
                        width: pill.cellWidth
                        height: pill.cellHeight

                        readonly property date cellDate: {
                            const view = panel.viewDate
                            const first = new Date(view.getFullYear(), view.getMonth(), 1)
                            const startOffset = -first.getDay()
                            return new Date(
                                first.getFullYear(),
                                first.getMonth(),
                                first.getDate() + startOffset + cell.index
                            )
                        }
                        readonly property bool inCurrentMonth:
                            cellDate.getMonth() === panel.viewDate.getMonth()
                            && cellDate.getFullYear() === panel.viewDate.getFullYear()
                        readonly property bool isToday:
                            panel.sameYMD(cellDate, panel.todayDate)

                        Rectangle {
                            anchors.centerIn: parent
                            width: pill.cellWidth - 4
                            height: pill.cellHeight - 2
                            visible: cell.isToday
                            color: pill.todayTint
                            radius: 4
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.cellDate.getDate()
                            color: cell.inCurrentMonth
                                ? panel.paletteForeground
                                : pill.dimForeground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.bold: cell.isToday
                        }
                    }
                }
            }
        }
    }
}

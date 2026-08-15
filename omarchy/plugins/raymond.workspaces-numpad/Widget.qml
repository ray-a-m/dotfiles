// 3×3 numpad-arranged workspace grid, ported from the pre-Quattro GlassPill
// Workspaces.qml into an omarchy-shell bar widget. The cells map 1:1 to
// Raymond's Corne v4.1 numpad layer (KC_1..KC_9, see memory
// hardware_corne.md). Layout matches a physical numpad: top row 7-8-9,
// middle 4-5-6, bottom 1-2-3.
//
// Cell colors (bar theme colors, live-updated by the host):
//   - focused          : accent at 0.85 alpha
//   - exists in model  : bar background at 0.45 alpha
//   - otherwise        : bar background at 0.18 alpha (empty placeholder)
//   - border (all)     : bar foreground at 0.25 alpha, 1 px
//
// "Exists in model" is the working proxy for "has windows" because
// Hyprland.workspaces only contains workspaces that Hyprland keeps alive
// (those with windows + any currently-active workspace on a monitor).
//
// Cells touch (spacing 0); the 1 px per-cell border supplies the visible
// grid lines between adjacent cells — no enclosing chrome, the 3×3
// arrangement is strong enough Gestalt to read as a group.

import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "raymond.workspaces-numpad"

  // Row-major numpad order.
  readonly property var numpadIds: [7, 8, 9, 4, 5, 6, 1, 2, 3]

  // The left section paints no pill (see Bar.qml), so the grid is the whole
  // mark: three touching rows nearly filling the bar thickness.
  readonly property int cellSize: Math.max(6, Math.floor((root.barSize - 2) / 3))

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: grid.width
  implicitHeight: root.barSize

  Grid {
    id: grid
    anchors.centerIn: parent
    columns: 3
    rowSpacing: 0
    columnSpacing: 0

    Repeater {
      model: root.numpadIds

      Rectangle {
        id: cell

        required property int modelData
        readonly property var ws: root.workspaceById(modelData)
        readonly property bool focused: Hyprland.focusedWorkspace !== null
          && Hyprland.focusedWorkspace.id === modelData
        readonly property bool exists: ws !== null

        width: root.cellSize
        height: root.cellSize
        radius: 0
        color: focused
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.85)
          : exists
            ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.45)
            : Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.18)
        border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)
        border.width: 1

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(cell.modelData)
        }
      }
    }
  }
}

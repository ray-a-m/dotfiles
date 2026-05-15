// GlassPill — the visual primitive every Quickshell widget inherits from
// in the philosophy theme. A translucent rounded rectangle with a thin
// highlight border for edge catch. Compositor blur is applied externally
// via a Hyprland layerrule on the `quickshell-*` namespace (see
// hypr/windows.conf), so this surface itself stays a simple Rectangle.
//
// Per-instance: pass `tint` (usually `palette.background`) for the
// translucent fill base color, and `borderTint` (usually
// `palette.foreground`) for the edge highlight. Defaults assume a dark
// warm-coffee bg + cream highlight — the philosophy palette.

import QtQuick

Rectangle {
    id: root

    property color tint: "#24180C"
    property real tintAlpha: 0.22
    property color borderTint: "#F0D29F"
    property real borderTintAlpha: 0.15
    property int cornerRadius: 14

    color: Qt.rgba(tint.r, tint.g, tint.b, tintAlpha)
    radius: cornerRadius
    border.color: Qt.rgba(borderTint.r, borderTint.g, borderTint.b, borderTintAlpha)
    border.width: 1
}

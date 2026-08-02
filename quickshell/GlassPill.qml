// GlassPill — the visual primitive every Quickshell panel inherits from.
// A translucent rounded rectangle with a thin highlight border for edge
// catch. Compositor blur is applied externally via a Hyprland layerrule
// on the `quickshell-*` namespace (see hypr/windows.conf), so this
// surface itself stays a simple Rectangle.
//
// Per-instance: pass `tint` (usually `palette.background`) for the
// translucent fill base color, and `borderTint` (usually
// `palette.foreground`) for the edge highlight. Defaults are a dark
// fallback used only before a caller binds — kept from an earlier
// theme, still readable if a panel forgets to wire palette.

import QtQuick

Rectangle {
    id: root

    // Defaults match the committed baseline (Catppuccin Latte):
    // `#eff1f5` = Catppuccin `base`; `#4c4f69` = Catppuccin `text`. Callers
    // that bind `tint`/`borderTint` from the live palette override these;
    // the defaults exist so a panel with a mid-boot palette-read race
    // degrades to the right theme instead of a dark-warm-coffee flash.
    property color tint: "#eff1f5"
    property real tintAlpha: 0.22
    property color borderTint: "#4c4f69"
    property real borderTintAlpha: 0.15
    property int cornerRadius: 14

    color: Qt.rgba(tint.r, tint.g, tint.b, tintAlpha)
    radius: cornerRadius
    border.color: Qt.rgba(borderTint.r, borderTint.g, borderTint.b, borderTintAlpha)
    border.width: 1
}

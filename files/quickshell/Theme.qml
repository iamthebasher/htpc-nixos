pragma Singleton
import QtQuick
import Quickshell

// Colours, fonts and sizes. Glass look copied from Balthasar's theme.nix:
// translucent black panels over blur, accent #00a6b2, and "sunlit" edges
// (light from above: white at the top, accent-tinted or dark at the bottom).
//
// Everything is designed for a 1920x1080 logical screen (the TV: 4K at
// scale 2). `s` scales that to the real window, so the same layout works in
// the small dev window on Balthasar.
Singleton {
    property real s: 1
    function px(v) { return Math.round(v * s) }

    // The item glass panels blur (the backdrop of the window they're in).
    // Set by Shell. Null = no in-window blur (e.g. over apps on the TV,
    // where Hyprland's layer blur does it).
    property Item backdrop: null

    // Roboto on the HTPC; Noto Sans when prototyping on Balthasar
    readonly property string font: Qt.fontFamilies().indexOf("Roboto") >= 0 ? "Roboto" : "Noto Sans"

    readonly property color bg:      "#000000"
    readonly property color text:    "#f2f2f2"
    readonly property color dim:     "#aaaaaa"
    readonly property color accent:  "#00a6b2"
    readonly property color running: "#00d900"
    readonly property color danger:  "#e50000"   // theme.nix ui.danger: Close

    // glass fills (QML colours are #AARRGGBB)
    readonly property color glass:       "#66000000"   // panels and tiles, over blur
    readonly property color glassStrong: "#99000000"   // selected tile, launcher, settings
    readonly property color glassHover:  "#33ffffff"   // selected row in lists

    // sunlit edges (theme.nix glass.active-border / inactive-border)
    readonly property color edgeActiveTop:      "#ffffffff"
    readonly property color edgeActiveBottom:   "#7000a6b2"
    readonly property color edgeInactiveTop:    "#80ffffff"
    readonly property color edgeInactiveBottom: "#90000000"

    // drop shadows (theme.nix glass.shadow-*: light from above, falls slightly below)
    readonly property color shadowSubtle: "#44101010"   // everything
    readonly property color shadowHeavy:  "#b0000000"   // pill, selected tile, dialogs

    readonly property int anim: 160   // ms, matches Hyprland's calm curves
}

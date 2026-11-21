import QtQuick
import Quickshell
import Quickshell.Widgets

// One app on the ribbon: a glass card with the app icon. Grows and gets the
// sunlit "active" edge when selected; a dot marks apps that are running.
Item {
    id: tile
    required property var app
    property bool selected: false
    property var track: 0   // the ribbon's scroll position, for the glass blur
    // what the glass blurs; null on the TV overlay layer (Hyprland blurs there)
    property Item glassBackdrop: Theme.backdrop

    width: Theme.px(208)
    height: Theme.px(124)
    z: selected ? 1 : 0

    readonly property string iconName: app.kind === "home" ? "go-home" : (app.icon || "")
    readonly property string iconSource: iconName ? Quickshell.iconPath(iconName, true) : ""
    // custom card image (Settings > App cards), if one is set for this app
    readonly property string cardImage: Prefs.cards[app.name] || ""
    readonly property bool hasCard: cardImage !== "" && cardImg.status !== Image.Error

    GlassPanel {
        id: card
        anchors.fill: parent
        radius: Theme.px(20)
        backdrop: tile.glassBackdrop
        active: tile.selected
        elevated: tile.selected
        fill: tile.selected ? Theme.glassStrong : Theme.glass
        track: [tile.track, scale, tile.x]
        opacity: tile.app.installed === false ? 0.5 : 1
        scale: tile.selected ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        // full-bleed custom card, cropped to the tile, under the glass edge
        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            visible: tile.hasCard
            Image {
                id: cardImg
                anchors.fill: parent
                source: tile.cardImage !== "" ? "file://" + tile.cardImage : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 832   // 4x the tile's logical width: sharp at 4K + the grow
            }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: Theme.px(72)
            source: tile.iconSource
            visible: !tile.hasCard && tile.iconSource !== ""
        }

        // Home tile and apps without an icon: a symbol or the first letter
        Text {
            anchors.centerIn: parent
            visible: !tile.hasCard && tile.iconSource === ""
            text: tile.app.name.charAt(0)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(56)
            font.weight: Font.DemiBold
        }

        Rectangle {
            visible: tile.app.running
            width: Theme.px(12); height: width; radius: width / 2
            color: Theme.running
            anchors { top: parent.top; right: parent.right; margins: Theme.px(14) }
        }
    }
}

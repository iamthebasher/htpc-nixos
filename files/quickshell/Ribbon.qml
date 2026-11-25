import QtQuick

// A row of AppTiles driven by the remote: Left/Right to move, OK (Enter) to
// open, Del on a running app to close it. The selected app's name shows
// underneath.
// Fits on screen: centred. Too many apps: full width, scrolls to keep the
// selection in view, and the edges fade out to show there's more.
FocusScope {
    id: ribbon
    property var model: []
    property alias currentIndex: list.currentIndex
    signal activated(var app)
    signal closeRequested(var app)                 // Del on a running app
    property Item glassBackdrop: Theme.backdrop   // passed to the tiles

    readonly property var currentApp: model[list.currentIndex] || null
    // where the selected tile is, in the ribbon's coordinates (for things
    // drawn above it, like the overlay's Close button)
    readonly property real currentCenterX: list.currentItem
        ? holder.x + list.currentItem.x - list.contentX + list.currentItem.width / 2 : width / 2
    readonly property real currentTop: (holder.height - tileH * 1.12) / 2   // the grown tile's top edge

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && currentApp && currentApp.running) {
            closeRequested(currentApp);
            event.accepted = true;
        }
    }

    readonly property real tileW: Theme.px(208)
    readonly property real tileH: Theme.px(124)
    readonly property real gap: Theme.px(28)
    readonly property real edge: Theme.px(96)   // side margin, and the fade width
    readonly property real rowWidth: model.length * tileW + Math.max(0, model.length - 1) * gap
    readonly property bool overflows: rowWidth + 2 * edge > width

    implicitHeight: list.height + Theme.px(56)

    Item {
        id: holder
        // room above/below for the selected tile's grow
        height: ribbon.tileH * 1.4
        width: ribbon.overflows ? ribbon.width : ribbon.rowWidth + 2 * ribbon.edge
        anchors.horizontalCenter: parent.horizontalCenter

        ListView {
            id: list
            anchors.fill: parent
            focus: true
            orientation: ListView.Horizontal
            spacing: ribbon.gap
            model: ribbon.model
            interactive: ribbon.overflows       // mouse/touch dragging
            keyNavigationEnabled: true          // defaults to `interactive`: keep arrows working
            keyNavigationWraps: false
            highlightMoveDuration: Theme.anim * 2
            leftMargin: ribbon.edge
            rightMargin: ribbon.edge
            preferredHighlightBegin: ribbon.edge * 1.5
            preferredHighlightEnd: width - ribbon.edge * 1.5
            highlightRangeMode: ribbon.overflows ? ListView.ApplyRange : ListView.NoHighlightRange

            // a full-height slot per tile, so the tile centres itself
            // vertically (ListView only manages x for a horizontal list)
            delegate: Item {
                id: slot
                required property var modelData
                required property int index
                width: ribbon.tileW
                height: list.height
                // edge fade when the row scrolls: tiles near or past the
                // screen edge fade out, hinting there's more that way
                readonly property real onScreenX: x - list.contentX
                readonly property real edgeRoom: Math.min(onScreenX, list.width - onScreenX - width)
                opacity: ribbon.overflows ? Math.max(0.08, Math.min(1, (edgeRoom + width * 0.25) / ribbon.edge)) : 1
                AppTile {
                    anchors.centerIn: parent
                    app: slot.modelData
                    selected: ribbon.activeFocus && slot.ListView.isCurrentItem
                    track: [list.contentX, slot.x]
                    glassBackdrop: ribbon.glassBackdrop
                }
            }

            Keys.onReturnPressed: ribbon.activated(ribbon.model[currentIndex])
            Keys.onEnterPressed: ribbon.activated(ribbon.model[currentIndex])
            Keys.onSelectPressed: ribbon.activated(ribbon.model[currentIndex])
        }
    }

    Text {
        anchors { top: holder.bottom; topMargin: -Theme.px(4) }
        x: list.currentItem ? holder.x + list.currentItem.x - list.contentX + list.currentItem.width / 2 - width / 2 : 0
        visible: ribbon.activeFocus && list.currentItem !== null
        text: !ribbon.currentApp ? "" : ribbon.currentApp.name + (Apps.isStuck(ribbon.currentApp) ? "  ·  not responding, Del to force quit" : "")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(26)
        font.weight: Font.Medium
        style: Text.Raised
        styleColor: "#80000000"
        Behavior on x { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } }
    }
}

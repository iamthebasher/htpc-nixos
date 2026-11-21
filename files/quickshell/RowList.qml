import QtQuick

// A settings-style list: title on the left, current value on the right.
// model: [{ title, value }]. OK emits picked(index), Back emits backRequested().
ListView {
    id: rl
    signal picked(int index)
    signal backRequested()

    clip: true
    spacing: Theme.px(8)
    highlightMoveDuration: Theme.anim
    highlight: Rectangle { radius: Theme.px(18); color: Theme.glassHover; border.width: Theme.px(2); border.color: Theme.accent }

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        width: ListView.view.width
        height: Theme.px(80)
        Text {
            anchors { left: parent.left; leftMargin: Theme.px(24); verticalCenter: parent.verticalCenter }
            text: row.modelData.title
            color: Theme.text
            font { family: Theme.font; pixelSize: Theme.px(28) }
        }
        Text {
            anchors { right: parent.right; rightMargin: Theme.px(24); verticalCenter: parent.verticalCenter }
            text: row.modelData.value
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.px(24) }
        }
        MouseArea { anchors.fill: parent; onClicked: { rl.currentIndex = row.index; rl.picked(row.index); } }
    }

    Keys.onReturnPressed: picked(currentIndex)
    Keys.onEnterPressed: picked(currentIndex)
    Keys.onEscapePressed: backRequested()
    Keys.onBackPressed: backRequested()
}

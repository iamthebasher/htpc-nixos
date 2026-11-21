import QtQuick
import Quickshell
import Quickshell.Widgets

// Search (the remote's Search key): type on the remote's keyboard, Up/Down
// through matches, OK to open, Back to close. Lists every desktop app.
FocusScope {
    id: launcher
    property bool open: false
    signal closeRequested()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    onOpenChanged: if (open) { input.text = ""; list.currentIndex = 0; input.forceActiveFocus(); }

    // Simple ranking: name prefix > word prefix > anywhere in name/keywords
    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        if (q === "") return apps.slice().sort((a, b) => a.name.localeCompare(b.name));
        const scored = [];
        for (const e of apps) {
            const name = e.name.toLowerCase();
            const extra = [e.genericName, e.comment, ...(e.keywords || [])].join(" ").toLowerCase();
            let score = -1;
            if (name.startsWith(q)) score = 3;
            else if (name.split(/\s+/).some(w => w.startsWith(q))) score = 2;
            else if (name.includes(q)) score = 1;
            else if (extra.includes(q)) score = 0;
            if (score >= 0) scored.push({ e, score });
        }
        scored.sort((a, b) => b.score - a.score || a.e.name.localeCompare(b.e.name));
        return scored.map(s => s.e);
    }

    function launch(entry) {
        if (!entry) return;
        launcher.closeRequested();
        entry.execute();
    }

    Rectangle { anchors.fill: parent; color: "#80000000" }
    MouseArea { anchors.fill: parent; onClicked: launcher.closeRequested() }

    GlassPanel {
        id: panel
        width: Theme.px(860)
        height: Theme.px(700)
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.px(150) }
        radius: Theme.px(28)
        fill: Theme.glassStrong
        active: true
        elevated: true
        scale: launcher.open ? 1 : 0.96
        track: scale
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // clicks inside don't close it

        Rectangle {
            id: field
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.px(28) }
            height: Theme.px(72)
            radius: height / 2
            color: "#40000000"
            border.width: Theme.px(2)
            border.color: input.activeFocus ? Theme.accent : "transparent"

            IconImage {
                id: glass
                anchors { left: parent.left; leftMargin: Theme.px(28); verticalCenter: parent.verticalCenter }
                implicitSize: Theme.px(32)
                source: Quickshell.iconPath("system-search")
            }
            TextInput {
                id: input
                anchors { left: glass.right; leftMargin: Theme.px(16); right: parent.right; rightMargin: Theme.px(28); verticalCenter: parent.verticalCenter }
                color: Theme.text
                font { family: Theme.font; pixelSize: Theme.px(30) }
                selectionColor: Theme.accent
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onReturnPressed: launcher.launch(launcher.results[list.currentIndex])
                Keys.onEnterPressed: launcher.launch(launcher.results[list.currentIndex])
                Keys.onEscapePressed: launcher.closeRequested()
                Keys.onBackPressed: launcher.closeRequested()

                Text {
                    visible: input.text === ""
                    text: "Search apps"
                    color: Theme.dim
                    font: input.font
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: field.bottom; bottom: parent.bottom; margins: Theme.px(20); topMargin: Theme.px(16) }
            clip: true
            model: launcher.results
            spacing: Theme.px(4)
            highlightMoveDuration: Theme.anim
            highlight: Rectangle { radius: Theme.px(16); color: Theme.glassHover; border.width: Theme.px(2); border.color: Theme.accent }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Theme.px(72)

                IconImage {
                    id: icon
                    anchors { left: parent.left; leftMargin: Theme.px(18); verticalCenter: parent.verticalCenter }
                    implicitSize: Theme.px(44)
                    source: Quickshell.iconPath(row.modelData.icon, true)
                }
                Column {
                    anchors { left: icon.right; leftMargin: Theme.px(18); right: parent.right; verticalCenter: parent.verticalCenter }
                    Text {
                        text: row.modelData.name
                        color: Theme.text
                        elide: Text.ElideRight
                        width: parent.width
                        font { family: Theme.font; pixelSize: Theme.px(26) }
                    }
                    Text {
                        visible: text !== ""
                        text: row.modelData.genericName || ""
                        color: Theme.dim
                        elide: Text.ElideRight
                        width: parent.width
                        font { family: Theme.font; pixelSize: Theme.px(18) }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: launcher.launch(row.modelData) }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No apps match"
                color: Theme.dim
                font { family: Theme.font; pixelSize: Theme.px(24) }
            }
        }
    }
}

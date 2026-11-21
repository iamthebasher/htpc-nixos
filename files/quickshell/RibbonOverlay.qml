import QtQuick

// Home pressed while an app is open: the ribbon slides up over the app
// (dimmed), with Home first and running apps next. Back closes it.
FocusScope {
    id: overlay
    property bool open: false
    signal closeRequested()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    onOpenChanged: if (open) { ribbon.currentIndex = Math.min(1, Apps.switcher.length - 1); ribbon.forceActiveFocus(); }

    Rectangle {   // dim the app underneath, darkest behind the ribbon
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a000000" }
            GradientStop { position: 0.55; color: "#66000000" }
            GradientStop { position: 1.0; color: "#cc000000" }
        }
    }

    Ribbon {
        id: ribbon
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.bottomMargin: overlay.open ? Theme.px(8) : -Theme.px(200)
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.anim * 1.5; easing.type: Easing.OutCubic } }
        model: Apps.switcher
        onActivated: app => { overlay.closeRequested(); Apps.activate(app); }
        Keys.onEscapePressed: overlay.closeRequested()
        Keys.onBackPressed: overlay.closeRequested()
    }
}

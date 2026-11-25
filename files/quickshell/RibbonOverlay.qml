import QtQuick
import Quickshell
import Quickshell.Widgets

// Home pressed while an app is open: the ribbon slides up over the app
// (dimmed), with Home first and running apps next. Back closes it.
// Closing apps: on a running app, Up focuses the Close button above its
// tile (OK closes, Down/Back cancels); Del closes it straight away. If the
// app hasn't closed after a few seconds (hung), the button says Force quit
// and closing again kills it (Apps.close).
FocusScope {
    id: overlay
    property bool open: false
    signal closeRequested()
    // what the glass blurs; null on the TV overlay layer (Hyprland blurs there)
    property Item glassBackdrop: Theme.backdrop

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    onOpenChanged: if (open) { ribbon.currentIndex = Math.min(1, Apps.switcher.length - 1); ribbon.forceActiveFocus(); }

    function closeApp(app) {
        Apps.close(app);
        ribbon.forceActiveFocus();
    }

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
        glassBackdrop: overlay.glassBackdrop
        onActivated: app => { overlay.closeRequested(); Apps.activate(app); }
        onCloseRequested: app => overlay.closeApp(app)
        Keys.onUpPressed: if (currentApp && currentApp.running) closeButton.forceActiveFocus()
        Keys.onEscapePressed: overlay.closeRequested()
        Keys.onBackPressed: overlay.closeRequested()
    }

    // Close button above the selected running app's tile
    Item {
        id: closeButton
        readonly property bool shown: overlay.open && ribbon.currentApp !== null && ribbon.currentApp.running === true
        width: label.implicitWidth + Theme.px(90)
        height: Theme.px(52)
        x: ribbon.x + ribbon.currentCenterX - width / 2
        y: ribbon.y + ribbon.currentTop - height - Theme.px(14)
        visible: opacity > 0
        // a faint hint while the ribbon has focus, full when focused
        opacity: !shown ? 0 : (activeFocus ? 1 : 0.55)
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on x { NumberAnimation { duration: Theme.anim * 2; easing.type: Easing.OutCubic } }
        onShownChanged: if (!shown && activeFocus) ribbon.forceActiveFocus()

        GlassPanel {
            anchors.fill: parent
            radius: height / 2
            backdrop: overlay.glassBackdrop
            active: closeButton.activeFocus
            elevated: closeButton.activeFocus
            fill: closeButton.activeFocus ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.55) : Theme.glass
        }
        Row {
            id: label
            anchors.centerIn: parent
            spacing: Theme.px(8)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !closeButton.activeFocus
                text: "▲"
                color: Theme.dim
                font { family: Theme.font; pixelSize: Theme.px(16) }
            }
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                visible: closeButton.activeFocus
                implicitSize: Theme.px(22)
                source: Quickshell.iconPath("window-close", true)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Apps.isStuck(ribbon.currentApp) ? "Force quit" : "Close"
                color: Theme.text
                font { family: Theme.font; pixelSize: Theme.px(22); weight: Font.Medium }
            }
        }

        Keys.onReturnPressed: overlay.closeApp(ribbon.currentApp)
        Keys.onEnterPressed: overlay.closeApp(ribbon.currentApp)
        Keys.onDownPressed: ribbon.forceActiveFocus()
        Keys.onEscapePressed: ribbon.forceActiveFocus()
        Keys.onBackPressed: ribbon.forceActiveFocus()
        Keys.onLeftPressed: { ribbon.forceActiveFocus(); ribbon.currentIndex = Math.max(0, ribbon.currentIndex - 1); }
        Keys.onRightPressed: { ribbon.forceActiveFocus(); ribbon.currentIndex = Math.min(ribbon.model.length - 1, ribbon.currentIndex + 1); }
    }
}

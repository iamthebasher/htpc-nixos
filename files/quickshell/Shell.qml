import QtQuick
import Quickshell

// The dev version: everything in one item, for a window on Balthasar.
// (The TV splits it across two layer-shell windows: TvShell.qml.)
// Keys standing in for the remote: H = Home, / = Search, A = pretend app,
// Esc = Back.
FocusScope {
    id: root

    Binding { target: Theme; property: "s"; value: Math.min(root.width / 1920, root.height / 1080) }
    Binding { target: Theme; property: "backdrop"; value: scene }
    Component.onCompleted: ShellState.dev = true

    // Keep keyboard focus somewhere that reaches the key handler below:
    // hiding the home screen (pretend app) would otherwise leave it nowhere.
    function refocus() {
        if (ShellState.mode !== "home") return;
        if (homeScreen.visible) homeScreen.forceActiveFocus();
        else root.forceActiveFocus();
    }
    Connections {
        target: ShellState
        function onModeChanged() { root.refocus(); }
        function onDevAppOpenChanged() { Qt.callLater(root.refocus); }
    }

    // What the glass blurs: the backdrop, plus the pretend app.
    Item {
        id: scene
        anchors.fill: parent

        Backdrop { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            visible: ShellState.devAppOpen
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3a2a5c" }
                GradientStop { position: 1.0; color: "#1c3b4a" }
            }
            Text {
                anchors.centerIn: parent
                text: "(pretend app: press H for the ribbon)"
                color: "#e0d4ff"
                font { family: Theme.font; pixelSize: Theme.px(40) }
            }
        }
    }

    Home {
        id: homeScreen
        anchors.fill: parent
        focus: true
        visible: !ShellState.devAppOpen
        onSettingsRequested: ShellState.settings()
    }

    RibbonOverlay { anchors.fill: parent; open: ShellState.mode === "switcher"; onCloseRequested: ShellState.back() }
    Launcher      { anchors.fill: parent; open: ShellState.mode === "launcher"; onCloseRequested: ShellState.back() }
    SettingsPanel { anchors.fill: parent; open: ShellState.mode === "settings"; onCloseRequested: ShellState.back() }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_HomePage || k === Qt.Key_H) ShellState.home();
        else if (k === Qt.Key_Search || k === Qt.Key_Slash) ShellState.search();
        else if (k === Qt.Key_Back || k === Qt.Key_Escape) ShellState.back();
        else if (k === Qt.Key_A) { ShellState.devAppOpen = !ShellState.devAppOpen; ShellState.mode = "home"; }
        else return;
        event.accepted = true;
    }
}

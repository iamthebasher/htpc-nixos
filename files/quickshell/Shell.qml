import QtQuick
import Quickshell
import Quickshell.Io

// Everything the shell shows, in one item, plus the remote-key logic:
//   Home   -> home screen, or the ribbon over the open app
//   Search -> launcher
//   Back   -> close whatever is open
// On the TV the keys arrive from Hyprland binds (`qs ipc call shell ...`).
// In the dev window on Balthasar: H = Home, / = Search, A = fake app, Esc = Back.
FocusScope {
    id: root
    property bool dev: false
    property string mode: "home"      // "home" | "switcher" | "launcher" | "settings"
    property bool appOpen: false      // dev only: a pretend app covering home

    Binding { target: Theme; property: "s"; value: Math.min(root.width / 1920, root.height / 1080) }
    Binding { target: Theme; property: "backdrop"; value: scene }

    function home() {
        if (mode !== "home") { mode = "home"; return; }
        if (appOpen) mode = "switcher";
    }
    function search() { mode = (mode === "launcher") ? "home" : "launcher"; }
    function back() { mode = "home"; }

    // Keep keyboard focus somewhere that reaches these handlers: hiding the
    // home screen (pretend app) would otherwise leave focus on nothing.
    function refocus() {
        if (mode !== "home") return;
        if (homeScreen.visible) homeScreen.forceActiveFocus();
        else root.forceActiveFocus();
    }
    onModeChanged: refocus()
    onAppOpenChanged: Qt.callLater(refocus)

    // What the glass blurs: the backdrop, plus (dev) the pretend app.
    // Kept apart from the panels themselves, which can't blur their own window.
    Item {
        id: scene
        anchors.fill: parent

        Backdrop { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            visible: root.dev && root.appOpen
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
        visible: !(root.dev && root.appOpen)
        onSettingsRequested: root.mode = "settings"
    }

    RibbonOverlay {
        anchors.fill: parent
        open: root.mode === "switcher"
        onCloseRequested: root.back()
    }

    Launcher {
        anchors.fill: parent
        open: root.mode === "launcher"
        onCloseRequested: root.back()
    }

    SettingsPanel {
        anchors.fill: parent
        open: root.mode === "settings"
        onCloseRequested: root.back()
    }

    // remote keys that nothing else handled
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_HomePage || (root.dev && k === Qt.Key_H)) root.home();
        else if (k === Qt.Key_Search || (root.dev && k === Qt.Key_Slash)) root.search();
        else if (k === Qt.Key_Back || k === Qt.Key_Escape) root.back();
        else if (root.dev && k === Qt.Key_A) { root.appOpen = !root.appOpen; root.mode = "home"; }
        else return;
        event.accepted = true;
    }

    // `qs ipc call shell home|search|back` (Hyprland binds on the TV)
    IpcHandler {
        target: "shell"
        function home(): void { root.home(); }
        function search(): void { root.search(); }
        function back(): void { root.back(); }
        // dev: toggle the pretend app
        function fakeApp(): void { root.appOpen = !root.appOpen; root.mode = "home"; }
        function settings(): void { root.mode = "settings"; }
    }
}

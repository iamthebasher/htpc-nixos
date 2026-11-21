import QtQuick
import Quickshell
import Quickshell.Wayland

// The TV version: two fullscreen layer-shell windows.
//  - Home: Hyprland's background layer, under every app. Home = an empty
//    workspace, so it shows whenever nothing covers it. It takes the remote's
//    keys only then (and only when no overlay is up).
//  - Overlays: the overlay layer, above everything, only while the ribbon,
//    launcher or settings is open; takes the keys while up. Hyprland blurs
//    behind it (layer rule on the "htpc-overlay" namespace), so its glass
//    doesn't blur in-window.
Scope {
    id: tv

    PanelWindow {
        id: homeWin
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bg
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "htpc-home"
        WlrLayershell.keyboardFocus: (ShellState.mode === "home" && !ShellState.appOpen)
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Binding { target: Theme; property: "s"; value: Math.min(homeWin.width / 1920, homeWin.height / 1080) }
        Binding { target: Theme; property: "backdrop"; value: scene }

        Item { id: scene; anchors.fill: parent; Backdrop { anchors.fill: parent } }

        Home {
            id: homeScreen
            anchors.fill: parent
            focus: true
            onSettingsRequested: ShellState.settings()
            // Search reaches us only when the home screen has focus (no app
            // covering it); in an app the app gets it. Not a Hyprland bind.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Search) { ShellState.search(); event.accepted = true; }
            }
        }
        Connections {
            target: ShellState
            function onModeChanged() { if (ShellState.mode === "home") homeScreen.forceActiveFocus(); }
        }
    }

    PanelWindow {
        id: overlayWin
        // mapped while anything is open or still fading out
        visible: ShellState.mode !== "home" || switcher.opacity > 0 || launcher.opacity > 0 || settings.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "htpc-overlay"
        WlrLayershell.keyboardFocus: ShellState.mode !== "home" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        FocusScope {
            anchors.fill: parent
            focus: true
            // while an overlay is up: Search toggles the launcher, Back closes
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Search) ShellState.search();
                else if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) ShellState.back();
                else return;
                event.accepted = true;
            }
            RibbonOverlay { id: switcher; anchors.fill: parent; glassBackdrop: null; open: ShellState.mode === "switcher"; onCloseRequested: ShellState.back() }
            Launcher      { id: launcher; anchors.fill: parent; glassBackdrop: null; open: ShellState.mode === "launcher"; onCloseRequested: ShellState.back() }
            SettingsPanel { id: settings; anchors.fill: parent; glassBackdrop: null; open: ShellState.mode === "settings"; onCloseRequested: ShellState.back() }
        }
    }
}

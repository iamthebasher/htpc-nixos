//@ pragma IconTheme Strata
import QtQuick
import Quickshell
import Quickshell.Io

// HTPC shell entry point.
//   HTPC_SHELL=tv  (set by Hyprland's autostart on the HTPC): TvShell, the
//                  home screen + overlays as layer-shell windows.
//   otherwise:     the dev window on Balthasar (1280x720, keyboard stands in
//                  for the remote: H Home, / Search, A pretend app, Esc Back).
ShellRoot {
    id: shellRoot
    readonly property bool tv: Quickshell.env("HTPC_SHELL") === "tv"

    LazyLoader { active: shellRoot.tv; component: TvShell {} }

    LazyLoader {
        active: !shellRoot.tv
        component: FloatingWindow {
            title: "HTPC shell (dev)"
            implicitWidth: 1280
            implicitHeight: 720
            color: Theme.bg
            Shell { anchors.fill: parent; focus: true }
        }
    }

    // `qs -p <dir> ipc call shell home|search|back|settings`
    // (the remote's Home and Search buttons are Hyprland binds calling these)
    IpcHandler {
        target: "shell"
        function home(): void { ShellState.home(); }
        function search(): void { ShellState.search(); }
        function back(): void { ShellState.back(); }
        function settings(): void { ShellState.settings(); }
        // dev: toggle the pretend app
        function fakeApp(): void { ShellState.devAppOpen = !ShellState.devAppOpen; ShellState.mode = "home"; }
    }
}

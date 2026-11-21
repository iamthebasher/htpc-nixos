//@ pragma IconTheme Strata
import QtQuick
import Quickshell

// HTPC shell entry point. Prototype stage: runs in a 1280x720 window on
// Balthasar (HTPC_SHELL_DEV=1 or anything that isn't the TV). The TV setup
// (background-layer home screen + overlay-layer switcher/launcher) comes
// once the UI settles.
ShellRoot {
    FloatingWindow {
        id: win
        title: "HTPC shell (dev)"
        implicitWidth: 1280
        implicitHeight: 720
        color: Theme.bg

        Shell {
            anchors.fill: parent
            focus: true
            dev: true
        }
    }
}

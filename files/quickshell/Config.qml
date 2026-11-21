pragma Singleton
import QtQuick
import Quickshell

// What's on the ribbon, and other per-machine settings. Later generated from
// Nix (services.htpc.desktop.shell.*); hand-written while prototyping.
Singleton {
    // The ribbon's app lineup, in order.
    //  desktop: desktop entry id (file name without .desktop), used for the
    //           icon and to launch it
    //  command: fallback launch command if there's no desktop entry
    //  match:   regex on the window class, to find it when it's running
    readonly property var apps: [
        { name: "Stremio",   desktop: "io.github.revenge977.StremioLinuxShellEnhanced", match: "StremioLinuxShellEnhanced", command: [] },
        { name: "Jellyfin",  desktop: "com.github.iwalton3.jellyfin-media-player",      match: "jellyfin",                   command: [] },
        { name: "YouTube",   desktop: "rocks.shy.VacuumTube",                           match: "vacuumtube",                 command: [] },
        { name: "Live TV",   desktop: "dev.fredol.open-tv",                             match: "open-tv",                    command: [] },
        { name: "Steam",     desktop: "steam",                                          match: "^steam$",                    command: ["steam", "-gamepadui"] },
        { name: "Moonlight", desktop: "com.moonlight_stream.Moonlight",                 match: "moonlight",                  command: [] }
    ]

    // Weather location and units are set from the shell's Settings screen
    // (Prefs.qml, saved on the machine), not here: this file is public.
}

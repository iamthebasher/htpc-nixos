pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings changed from the shell's Settings screen. Saved as JSON in
// quickshell's per-shell state directory on the machine itself
// (~/.local/state/quickshell/...), never in the repo, so things like the
// weather location stay private.
Singleton {
    property alias weather: prefs.weather        // { name, lat, lon } or null
    property alias unit: prefs.unit              // "fahrenheit" | "celsius"
    property alias wallpaper: prefs.wallpaper    // image path, "" = built-in backdrop
    property alias wallpaperRotate: prefs.wallpaperRotate  // minutes between wallpapers, 0 = off
    property alias cards: prefs.cards            // { "App name": "/path/to/image.png" }

    // Wallpapers are picked from here (Settings > Wallpaper); same folder as
    // Balthasar's waypaper. Copy them over; nothing ships in the repo.
    readonly property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/wallpaper"

    // Where custom card images are picked from (Settings > App cards).
    // Copy images here on the HTPC; nothing ships in the repo.
    readonly property string cardsDir: Quickshell.env("HOME") + "/Pictures/htpc-cards"

    function setCard(appName, path) {
        const next = Object.assign({}, prefs.cards);
        if (path) next[appName] = path; else delete next[appName];
        prefs.cards = next;   // reassign so bindings see the change
    }

    FileView {
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // a missing file on first run is fine: defaults apply
        printErrors: false

        JsonAdapter {
            id: prefs
            property var weather: null
            property string unit: "fahrenheit"
            property string wallpaper: ""
            property int wallpaperRotate: 0
            property var cards: ({})
        }
    }
}

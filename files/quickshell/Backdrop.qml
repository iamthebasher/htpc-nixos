import QtQuick
import QtQuick.Shapes
import Qt.labs.folderlistmodel

// What's behind everything on the home screen, and what the glass blurs:
// the chosen wallpaper (Settings), optionally rotating through the whole
// wallpaper folder with a slow crossfade, or soft colour glows on black.
Item {
    id: backdrop

    Rectangle { anchors.fill: parent; color: Theme.bg }

    // --- built-in: a few large radial glows ---
    Item {
        anchors.fill: parent
        visible: backdrop.current === ""
        component Glow: Shape {
            id: glow
            property color tint
            opacity: 0.6
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: glow.width / 2; centerY: glow.height / 2; centerRadius: glow.width / 2
                    focalX: glow.width / 2; focalY: glow.height / 2
                    GradientStop { position: 0.0; color: glow.tint }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: glow.width; y: 0 }
                PathLine { x: glow.width; y: glow.height }
                PathLine { x: 0; y: glow.height }
                PathLine { x: 0; y: 0 }
            }
        }
        Glow { tint: "#0d6b73"; width: parent.width * 0.7; height: width; x: -width * 0.15; y: parent.height * 0.35 }
        Glow { tint: "#1a3a8f"; width: parent.width * 0.55; height: width; x: parent.width * 0.55; y: -height * 0.25 }
        Glow { tint: "#3d1a6b"; width: parent.width * 0.4; height: width; x: parent.width * 0.35; y: parent.height * 0.55 }
    }

    // --- wallpaper(s) ---
    FolderListModel {
        id: walls
        folder: "file://" + Prefs.wallpapersDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    property int rotateIndex: 0
    readonly property bool rotating: Prefs.wallpaperRotate > 0 && walls.count > 1
    readonly property string current: rotating ? (walls.get(rotateIndex % walls.count, "filePath") || "") : Prefs.wallpaper

    Timer {
        interval: Math.max(1, Prefs.wallpaperRotate) * 60 * 1000
        running: backdrop.rotating
        repeat: true
        onTriggered: backdrop.rotateIndex = (backdrop.rotateIndex + 1) % walls.count
    }
    // start the rotation at the chosen wallpaper
    onRotatingChanged: if (rotating) {
        for (let i = 0; i < walls.count; i++)
            if (walls.get(i, "filePath") === Prefs.wallpaper) { rotateIndex = i; break; }
    }

    // two layers so a change crossfades instead of flashing
    property bool showA: true
    onCurrentChanged: {
        if (current === "") return;
        const next = showA ? layerB : layerA;
        next.source = "file://" + current;
        showA = !showA;
    }
    Image {
        id: layerA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1920 * 2   // the TV is 4K
        opacity: backdrop.current !== "" && backdrop.showA && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
    }
    Image {
        id: layerB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1920 * 2
        opacity: backdrop.current !== "" && !backdrop.showA && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
    }
    Component.onCompleted: if (current !== "") { layerA.source = "file://" + current; }

    // darken the wallpaper a touch so text and glass stay readable
    Rectangle { anchors.fill: parent; color: "#33000000"; visible: backdrop.current !== "" }
}

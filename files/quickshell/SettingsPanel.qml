import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

// Settings (the gear in the pill). Saved by Prefs on the machine, not in the
// repo. Up/Down picks, OK changes, Back goes up a page (or closes).
//   Weather location  type a city, pick a match (Open-Meteo geocoding)
//   Temperature       °F / °C
//   App cards         per ribbon app: an image from Prefs.cardsDir, or the icon
//   Update apps       update the flatpaks now (they also update on a timer)
FocusScope {
    id: panelRoot
    property bool open: false
    signal closeRequested()
    // what the glass blurs; null on the TV overlay layer (Hyprland blurs there)
    property Item glassBackdrop: Theme.backdrop

    property string page: "main"      // main | city | cards | image
    property var matches: []          // city search results
    property string cardApp: ""       // app whose card is being picked
    property string pickerFor: "card" // what the image picker sets: "card" | "wallpaper"
    readonly property string pickerDir: pickerFor === "wallpaper" ? Prefs.wallpapersDir : Prefs.cardsDir

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    onOpenChanged: if (open) { go("main"); Updates.refresh(); }

    function go(p) {
        page = p;
        if (p === "main") { mainList.forceActiveFocus(); }
        else if (p === "city") { input.text = ""; matches = []; results.currentIndex = 0; input.forceActiveFocus(); }
        else if (p === "cards") { cardList.forceActiveFocus(); }
        else if (p === "image") { imageGrid.currentIndex = 0; imageGrid.forceActiveFocus(); }
    }
    function back() {
        if (page === "main") closeRequested();
        else if (page === "image") go(pickerFor === "wallpaper" ? "main" : "cards");
        else go("main");
    }

    // wallpaper rotation steps (minutes); OK cycles through them
    readonly property var rotateSteps: [0, 15, 60, 1440]
    function rotateLabel(m) {
        return ({ 0: "Off", 15: "Every 15 min", 60: "Every hour", 1440: "Daily" })[m] || `Every ${m} min`;
    }

    // --- main page ---
    readonly property var mainRows: [
        { key: "weather", title: "Weather location", value: Prefs.weather ? Prefs.weather.name : "Not set" },
        { key: "unit",    title: "Temperature",      value: Prefs.unit === "celsius" ? "°C" : "°F" },
        { key: "wallpaper", title: "Wallpaper",        value: fileName(Prefs.wallpaper) || "Built-in glow" },
        { key: "rotate",    title: "Change wallpaper", value: rotateLabel(Prefs.wallpaperRotate) },
        { key: "cards",     title: "App cards",        value: Object.keys(Prefs.cards).length + " custom" },
        { key: "updates",   title: "Update apps",      value: Updates.label }
    ].concat(Prefs.weather ? [{ key: "clear", title: "Remove weather location", value: "" }] : [])

    function activateMain(key) {
        if (key === "weather") go("city");
        else if (key === "unit") Prefs.unit = (Prefs.unit === "celsius") ? "fahrenheit" : "celsius";
        else if (key === "cards") go("cards");
        else if (key === "updates") Updates.start();
        else if (key === "wallpaper") { pickerFor = "wallpaper"; go("image"); }
        else if (key === "rotate") {
            const i = rotateSteps.indexOf(Prefs.wallpaperRotate);
            Prefs.wallpaperRotate = rotateSteps[(i + 1) % rotateSteps.length];
        }
        else if (key === "clear") { Prefs.weather = null; mainList.currentIndex = 0; }
    }

    // --- city search ---
    function geocode(q) {
        if (q.trim().length < 2) { matches = []; return; }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return;
            if (input.text !== q) return;   // stale reply
            panelRoot.matches = JSON.parse(xhr.responseText).results || [];
            results.currentIndex = 0;
        };
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&name=" + encodeURIComponent(q));
        xhr.send();
    }
    function pickCity(m) {
        if (!m) return;
        // city-level precision is plenty for weather
        Prefs.weather = { name: m.admin1 ? `${m.name}, ${m.admin1}` : m.name,
                          lat: Math.round(m.latitude * 100) / 100, lon: Math.round(m.longitude * 100) / 100 };
        go("main");
    }
    function cityLabel(m) { return [m.name, m.admin1, m.country].filter(x => x).join(", "); }

    // --- app cards ---
    function fileName(path) { return path ? path.split("/").pop() : ""; }
    FolderListModel {
        id: images
        folder: "file://" + panelRoot.pickerDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    // first entry of the picker is "use the icon"; the rest are images
    function pickImage(index) {
        const path = index === 0 ? "" : images.get(index - 1, "filePath");
        if (pickerFor === "wallpaper") { Prefs.wallpaper = path; go("main"); return; }
        if (index === 0) Prefs.setCard(cardApp, "");
        else Prefs.setCard(cardApp, images.get(index - 1, "filePath"));
        go("cards");
    }

    Rectangle { anchors.fill: parent; color: "#80000000" }
    MouseArea { anchors.fill: parent; onClicked: panelRoot.closeRequested() }

    GlassPanel {
        id: panel
        width: Theme.px(960)
        height: Theme.px(680)
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.px(130) }
        radius: Theme.px(28)
        fill: Theme.glassStrong
        backdrop: panelRoot.glassBackdrop
        active: true
        elevated: true
        scale: panelRoot.open ? 1 : 0.96
        track: scale
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // clicks inside don't close it

        Text {
            id: heading
            anchors { left: parent.left; top: parent.top; margins: Theme.px(36) }
            text: ({ main: "Settings", city: "Weather location", cards: "App cards",
                     image: panelRoot.pickerFor === "wallpaper" ? "Wallpaper" : `Card for ${panelRoot.cardApp}` })[panelRoot.page]
            color: Theme.text
            font { family: Theme.font; pixelSize: Theme.px(36); weight: Font.DemiBold }
        }

        Item {
            id: body
            anchors { left: parent.left; right: parent.right; top: heading.bottom; bottom: parent.bottom; margins: Theme.px(24); topMargin: Theme.px(24) }

            RowList {
                id: mainList
                anchors.fill: parent
                visible: panelRoot.page === "main"
                rows: panelRoot.mainRows
                onPicked: index => panelRoot.activateMain(panelRoot.mainRows[index].key)
                onBackRequested: panelRoot.back()
            }

            RowList {
                id: cardList
                anchors.fill: parent
                visible: panelRoot.page === "cards"
                onBackRequested: panelRoot.back()
                rows: Apps.lineup.map(a => ({ title: a.name, value: panelRoot.fileName(Prefs.cards[a.name]) || "Icon" }))
                onPicked: index => { panelRoot.cardApp = Apps.lineup[index].name; panelRoot.pickerFor = "card"; panelRoot.go("image"); }
            }

            // --- image picker: "Use icon" + every image in the cards folder ---
            Item {
                anchors.fill: parent
                visible: panelRoot.page === "image"

                GridView {
                    id: imageGrid
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: hint.top; bottomMargin: Theme.px(12) }
                    clip: true
                    cellWidth: width / 3
                    cellHeight: cellWidth * 124 / 208 + Theme.px(40)
                    model: images.count + 1
                    highlightMoveDuration: Theme.anim
                    keyNavigationEnabled: true
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property string path: index > 0 ? images.get(index - 1, "filePath") : ""
                        width: GridView.view.cellWidth
                        height: GridView.view.cellHeight
                        ClippingRectangle {
                            id: thumb
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.px(10) }
                            height: width * 124 / 208
                            radius: Theme.px(14)
                            color: "#40000000"
                            border.width: cell.GridView.isCurrentItem ? Theme.px(3) : Theme.px(1)
                            border.color: cell.GridView.isCurrentItem ? Theme.accent : "#40ffffff"
                            Image {
                                anchors.fill: parent
                                visible: cell.index > 0
                                source: cell.path !== "" ? "file://" + cell.path : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 416
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cell.index === 0
                                text: panelRoot.pickerFor === "wallpaper" ? "Built-in glow" : "Use icon"
                                color: Theme.text
                                font { family: Theme.font; pixelSize: Theme.px(24) }
                            }
                        }
                        Text {
                            anchors { top: thumb.bottom; topMargin: Theme.px(4); horizontalCenter: thumb.horizontalCenter }
                            width: thumb.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            text: cell.index > 0 ? panelRoot.fileName(cell.path) : ""
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: Theme.px(18) }
                        }
                        MouseArea { anchors.fill: parent; onClicked: panelRoot.pickImage(cell.index) }
                    }
                    Keys.onReturnPressed: panelRoot.pickImage(currentIndex)
                    Keys.onEnterPressed: panelRoot.pickImage(currentIndex)
                    Keys.onEscapePressed: panelRoot.back()
                    Keys.onBackPressed: panelRoot.back()
                }

                Text {
                    id: hint
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.px(12) }
                    wrapMode: Text.WordWrap
                    text: images.count === 0
                          ? `No images yet. Copy PNG/JPG/WebP files to ${panelRoot.pickerDir}` + (panelRoot.pickerFor === "card" ? " (16:9 looks best, e.g. 1280x720)." : " (3840x2160 for the 4K TV).")
                          : `Images from ${panelRoot.pickerDir}`
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: Theme.px(20) }
                }
            }

            // --- city search ---
            Item {
                anchors.fill: parent
                visible: panelRoot.page === "city"

                Rectangle {
                    id: field
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Theme.px(72)
                    radius: height / 2
                    color: "#40000000"
                    border.width: Theme.px(2)
                    border.color: Theme.accent
                    TextInput {
                        id: input
                        anchors { left: parent.left; right: parent.right; margins: Theme.px(28); verticalCenter: parent.verticalCenter }
                        color: Theme.text
                        font { family: Theme.font; pixelSize: Theme.px(30) }
                        onTextChanged: debounce.restart()
                        Keys.onDownPressed: results.incrementCurrentIndex()
                        Keys.onUpPressed: results.decrementCurrentIndex()
                        Keys.onReturnPressed: panelRoot.pickCity(panelRoot.matches[results.currentIndex])
                        Keys.onEnterPressed: panelRoot.pickCity(panelRoot.matches[results.currentIndex])
                        Keys.onEscapePressed: panelRoot.back()
                        Keys.onBackPressed: panelRoot.back()
                        Text {
                            visible: input.text === ""
                            text: "Type a city"
                            color: Theme.dim
                            font: input.font
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Timer { id: debounce; interval: 350; onTriggered: panelRoot.geocode(input.text) }
                }

                ListView {
                    id: results
                    anchors { left: parent.left; right: parent.right; top: field.bottom; bottom: parent.bottom; topMargin: Theme.px(16) }
                    clip: true
                    model: panelRoot.matches
                    spacing: Theme.px(4)
                    highlightMoveDuration: Theme.anim
                    highlight: Rectangle { radius: Theme.px(16); color: Theme.glassHover; border.width: Theme.px(2); border.color: Theme.accent }
                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width
                        height: Theme.px(64)
                        Text {
                            anchors { left: parent.left; leftMargin: Theme.px(24); right: parent.right; rightMargin: Theme.px(24); verticalCenter: parent.verticalCenter }
                            text: panelRoot.cityLabel(modelData)
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.font; pixelSize: Theme.px(26) }
                        }
                        MouseArea { anchors.fill: parent; onClicked: panelRoot.pickCity(modelData) }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: results.count === 0 && input.text.trim().length >= 2
                        text: "No matches yet"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.px(24) }
                    }
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Widgets

// Top-centre glass capsule: time, date, weather, and a settings button that
// can take focus (Up from the ribbon). Weather location is set in Settings.
FocusScope {
    id: pill
    signal settingsRequested()

    implicitWidth: row.implicitWidth + Theme.px(48)
    implicitHeight: Theme.px(64)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // --- weather (Open-Meteo, no API key; refreshed every 15 min) ---
    property string weather: ""
    property string weatherIcon: ""
    // WMO weather codes -> a few words + a freedesktop weather icon (Strata has them all)
    function weatherInfo(code, day) {
        if (code === 0)  return ["Clear",         day ? "weather-clear" : "weather-clear-night"];
        if (code <= 2)   return ["Partly cloudy", day ? "weather-few-clouds" : "weather-few-clouds-night"];
        if (code === 3)  return ["Cloudy",        "weather-overcast"];
        if (code <= 48)  return ["Fog",           "weather-fog"];
        if (code <= 57)  return ["Drizzle",       "weather-showers-scattered"];
        if (code <= 67)  return ["Rain",          "weather-showers"];
        if (code <= 77)  return ["Snow",          "weather-snow"];
        if (code <= 82)  return ["Showers",       "weather-showers"];
        if (code <= 86)  return ["Snow showers",  "weather-snow"];
        return ["Storms", "weather-storm"];
    }
    function refreshWeather() {
        const loc = Prefs.weather;
        if (!loc) { weather = ""; weatherIcon = ""; return; }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return;
            const c = JSON.parse(xhr.responseText).current;
            const [words, icon] = weatherInfo(c.weather_code, c.is_day === 1);
            pill.weather = `${Math.round(c.temperature_2m)}°  ${words}`;
            pill.weatherIcon = icon;
        };
        xhr.open("GET", `https://api.open-meteo.com/v1/forecast?latitude=${loc.lat}&longitude=${loc.lon}`
                 + `&current=temperature_2m,weather_code,is_day&temperature_unit=${Prefs.unit}`);
        xhr.send();
    }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pill.refreshWeather() }
    Connections {
        target: Prefs
        function onWeatherChanged() { pill.refreshWeather(); }
        function onUnitChanged() { pill.refreshWeather(); }
    }

    GlassPanel {
        anchors.fill: parent
        radius: height / 2
        active: pill.activeFocus
        elevated: true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(22)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "h:mm")
            color: Theme.text
            font { family: Theme.font; pixelSize: Theme.px(30); weight: Font.DemiBold }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.px(22) }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.weather !== ""
            spacing: Theme.px(8)
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Theme.px(26)
                source: pill.weatherIcon ? Quickshell.iconPath(pill.weatherIcon, true) : ""
                visible: source != ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.weather
                color: Theme.dim
                font { family: Theme.font; pixelSize: Theme.px(22) }
            }
        }

        // settings: the pill's one focusable control (Strata icons are
        // accent-coloured, so focus shows as a light fill + accent ring)
        Rectangle {
            id: settings
            focus: true
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(44); height: width; radius: width / 2
            color: activeFocus ? Theme.glassHover : "transparent"
            border.width: Theme.px(2)
            border.color: activeFocus ? Theme.accent : "#59ffffff"
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.px(26)
                source: Quickshell.iconPath("preferences-system")
            }
            Keys.onReturnPressed: pill.settingsRequested()
            Keys.onEnterPressed: pill.settingsRequested()
        }
    }
}

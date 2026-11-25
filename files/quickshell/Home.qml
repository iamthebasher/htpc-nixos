import QtQuick

// The home screen's controls: the pill up top and the app ribbon along the
// bottom, centred. Up/Down moves between them. (The backdrop they sit on is
// drawn by Shell, so the glass can blur it.)
FocusScope {
    id: home
    signal settingsRequested()

    Pill {
        id: pill
        anchors { top: parent.top; topMargin: Theme.px(22); horizontalCenter: parent.horizontalCenter }
        KeyNavigation.down: ribbon
        onSettingsRequested: home.settingsRequested()
    }

    Ribbon {
        id: ribbon
        focus: true
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.px(8) }
        model: Apps.lineup
        KeyNavigation.up: pill
        onActivated: app => Apps.activate(app)
        onCloseRequested: app => Apps.close(app)
    }
}

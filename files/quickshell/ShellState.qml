pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the shell is showing, shared by its windows, and the remote-key logic:
//   Home   -> over an app: the ribbon; again: the home screen
//   Search -> launcher (only on the home screen: in apps it's the app's key)
//   Back   -> close whatever is open
// On the TV, Home is a Hyprland bind (`qs ipc call shell home`), so it works
// everywhere. Search and Back aren't bound: they reach the shell only when
// it has keyboard focus (home screen, or one of its overlays), and the
// focused app otherwise.
Singleton {
    id: st
    property string mode: "home"      // "home" | "switcher" | "launcher" | "settings"
    property bool dev: false          // the dev window on Balthasar
    property bool devAppOpen: false   // dev only: the pretend app (A key)

    // An app covers the home screen: the dev pretend app, or on the TV the
    // focused workspace has windows (home = an empty workspace).
    readonly property bool appOpen: dev ? devAppOpen
        : (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.toplevels.values.length > 0)

    // Home: over an app, bring up the ribbon; pressed again (ribbon up), go
    // to the home screen; anything else open, close it.
    function home() {
        if (mode === "switcher") {
            mode = "home";
            if (dev) devAppOpen = false; else Apps.goHome();
            return;
        }
        if (mode !== "home") { mode = "home"; return; }
        if (appOpen) mode = "switcher";
    }
    function search() { mode = (mode === "launcher") ? "home" : "launcher"; }
    function back() { mode = "home"; }
    function settings() { mode = "settings"; }
}

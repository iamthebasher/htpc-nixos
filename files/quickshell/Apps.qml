pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Turns Config.apps into ribbon items (icon, desktop entry, running window)
// and does the launching/focusing. Hyprland 0.57 runs a Lua config, so
// dispatches are Lua expressions (hyprctl turns "X" into hl.dispatch(X)).
Singleton {
    id: root

    // Ribbon items for the home screen: the configured lineup.
    readonly property var lineup: {
        DesktopEntries.applications.values;  // re-evaluate when entries change
        Hyprland.toplevels.values;           // ... and when windows open/close
        return Config.apps.map(a => item(a));
    }

    // Items for the overlay over a running app: Home first, then everything
    // that's open (lineup apps and anything else), then the rest of the lineup.
    readonly property var switcher: {
        const items = [{ kind: "home", name: "Home", icon: "", running: false }];
        const lineupItems = lineup;
        for (const it of lineupItems) if (it.running) items.push(it);
        for (const t of Hyprland.toplevels.values) {
            const cls = windowClass(t);
            if (!cls || lineupItems.some(it => it.running && it.window === t)) continue;
            const entry = DesktopEntries.heuristicLookup(cls);
            items.push({ kind: "window", name: entry ? entry.name : cls, icon: entry ? entry.icon : cls,
                         running: true, window: t, entry: entry });
        }
        for (const it of lineupItems) if (!it.running) items.push(it);
        return items;
    }

    function item(a) {
        const entry = DesktopEntries.byId(a.desktop);
        const window = findWindow(a.match);
        return { kind: "app", name: a.name, icon: entry ? entry.icon : "", entry: entry,
                 command: a.command, running: window !== null, window: window, installed: entry !== null || a.command.length > 0 };
    }

    function windowClass(t) {
        if (t.wayland && t.wayland.appId) return t.wayland.appId;
        return t.lastIpcObject ? (t.lastIpcObject["class"] || "") : "";
    }

    function findWindow(pattern) {
        const re = new RegExp(pattern, "i");
        for (const t of Hyprland.toplevels.values) if (re.test(windowClass(t))) return t;
        return null;
    }

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }

    // Focus it if it's running, otherwise start it.
    function activate(it) {
        if (it.kind === "home") { goHome(); return; }
        if (it.window) {
            dispatch(`hl.dsp.focus({ window = "address:0x${it.window.address}" })`);
        } else if (it.entry) {
            it.entry.execute();
        } else if (it.command && it.command.length > 0) {
            Quickshell.execDetached(it.command);
        } else {
            console.log(`htpc: ${it.name} isn't installed`);
        }
    }

    // Home screen = an empty workspace, so nothing covers the background layer.
    function goHome() {
        dispatch(`hl.dsp.focus({ workspace = "empty" })`);
    }
}

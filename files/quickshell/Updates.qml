pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Flatpak app updates (Settings > Update apps). The update itself is the
// system unit from modules/system/flatpak-update.nix, which also runs on a
// timer. Its polkit rule lets the person at the TV start it with no password.
// This only starts the unit and reads its state with systemctl.
Singleton {
    id: up
    readonly property string unit: "htpc-flatpak-update"

    property bool available: false   // the unit exists on this machine
    property bool running: false
    property bool failed: false      // the last run failed
    property string error: ""        // couldn't start it
    property real lastRun: 0         // ms since the epoch, 0 = not known

    readonly property string label: {
        if (!available) return "Not set up here";
        if (running) return "Updating…";
        if (error) return error;
        if (failed) return "Last update failed";
        return lastRun > 0 ? "Updated " + ago(lastRun) : "Update now";
    }

    function ago(t) {
        clock.now;   // re-evaluate as time passes
        const min = Math.round((Date.now() - t) / 60000);
        if (min < 1) return "just now";
        if (min < 60) return `${min} min ago`;
        const h = Math.round(min / 60);
        return h < 24 ? `${h} h ago` : `${Math.round(h / 24)} d ago`;
    }

    function refresh() { if (!show.running) show.running = true; }

    function start() {
        if (!available || running) return;
        error = "";
        markStart();
        running = true;
        starter.running = true;
    }

    // `systemctl start --no-block` returns once the job is queued; a
    // non-zero exit means polkit refused or the unit is missing
    Process {
        id: starter
        command: ["systemctl", "start", "--no-block", up.unit + ".service"]
        onExited: (code, status) => {
            if (code !== 0) { up.running = false; up.error = "Couldn't start the update"; }
            up.refresh();
        }
    }

    // The service's state and when it last finished; the timer's last run
    // too, since the service's own timestamps reset at boot.
    Process {
        id: show
        command: ["systemctl", "show", "--timestamp=unix",
                  "-p", "LoadState", "-p", "ActiveState", "-p", "Result",
                  "-p", "ExecMainExitTimestamp", "-p", "LastTriggerUSec",
                  up.unit + ".service", up.unit + ".timer"]
        stdout: StdioCollector { onStreamFinished: up.parse(text) }
    }

    function parse(text) {
        // one key=value block per unit, separated by a blank line
        const blocks = text.trim().split(/\n\s*\n/).map(b => {
            const o = {};
            for (const line of b.split("\n")) {
                const i = line.indexOf("=");
                if (i > 0) o[line.slice(0, i)] = line.slice(i + 1);
            }
            return o;
        });
        const svc = blocks[0] || {};
        const tmr = blocks[1] || {};
        available = svc.LoadState === "loaded";
        if (!available) { running = false; return; }
        const unix = s => (s && s.startsWith("@")) ? Number(s.slice(1)) * 1000 : 0;
        const exited = unix(svc.ExecMainExitTimestamp);
        lastRun = Math.max(exited, unix(tmr.LastTriggerUSec));
        failed = svc.Result !== undefined && svc.Result !== "success";
        // a oneshot is "activating" while it runs (also when the timer
        // started it). Started from here: done once it has exited since.
        if (svc.ActiveState === "activating" || svc.ActiveState === "active") running = true;
        else if (running && !starter.running && exited >= startedAt) running = false;
    }
    property real startedAt: 0
    onRunningChanged: if (running) giveUp.restart()
    function markStart() { startedAt = Date.now() - 1000; }

    // in case the state is never seen changing, stop showing "Updating…"
    Timer { id: giveUp; interval: 15 * 60 * 1000; onTriggered: up.running = false }

    Timer {   // poll while updating
        interval: 2000
        repeat: true
        running: up.running
        onTriggered: up.refresh()
    }
    Timer { id: clock; property real now: Date.now(); interval: 60000; repeat: true; running: true; onTriggered: { now = Date.now(); } }

    Component.onCompleted: refresh()
}

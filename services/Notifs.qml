pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (replaces mako while this rice is on).
// `toasts` are the ones on screen right now; `history` is everything not yet dismissed, and `groups` is that
// by app, the app with the newest first (the control centre's timeline, panels/NotifCentre.qml).
Singleton {
    id: root

    property var toasts: []
    signal arrived(var n)                        // the dynamic island shows simple ones
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    // when each one came (by id; ones kept over a reload lost theirs), and a clock for "5m ago"
    property var times: ({})
    property real now: Date.now()
    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function ago(n) {
        const t = times[n.id];
        if (!t)
            return "earlier";
        const s = Math.max(0, (now - t) / 1000);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d";
    }

    // [{ app, icon, items (newest first) }], the app with the newest one first
    readonly property var groups: {
        const by = {}, last = {};
        history.forEach((n, i) => {
            const app = n.appName || "notice";
            if (!by[app])
                by[app] = { app, icon: n.appIcon, items: [] };
            by[app].items.unshift(n);
            last[app] = i;
        });
        return Object.values(by).sort((a, b) => last[b.app] - last[a.app]);
    }

    // dismiss a whole app's worth
    function dismissAll(list) {
        for (const n of list.slice())
            n.dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.now = Date.now();
            root.times = Object.assign({}, root.times, { [n.id]: root.now });
            n.closed.connect(() => root.drop(n));
            const critical = n.urgency === NotificationUrgency.Critical;
            if (Ui.dnd && !critical)
                return;
            Sounds.notify();
            // simple ones go to the island; ones with buttons, or critical ones, get the full popup
            if (Settings.islandNotifs && Ui.barVisible && !critical && n.actions.length === 0)
                root.arrived(n);
            else
                root.toasts = [n, ...root.toasts].slice(0, 4);
        }
    }

    // off the screen, still in the history
    function drop(n) {
        toasts = toasts.filter(t => t !== n);
    }

    // the control centre drains its list first when it's open; else straight away
    signal drainAsked
    IpcHandler {
        target: "notifs"
        function clear(): void {             // qs -c ekitai ipc call notifs clear
            if (Ui.panel === "control")
                root.drainAsked();
            else
                root.clear();
        }
        function count(): int {
            return root.count;
        }
    }

    function clear() {
        for (const n of history.slice())
            n.dismiss();
        toasts = [];
    }
}

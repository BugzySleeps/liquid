pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification daemon (replaces mako while this rice is on).
// `toasts` are the ones on screen right now; `history` is everything not yet dismissed.
Singleton {
    id: root

    property var toasts: []
    signal arrived(var n)                        // the dynamic island shows simple ones
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

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

    function clear() {
        for (const n of history.slice())
            n.dismiss();
        toasts = [];
    }
}

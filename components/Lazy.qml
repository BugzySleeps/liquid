import QtQuick
import Quickshell

// A window built only while it's wanted: settings, the launcher, the overview… cost nothing until you open
// them. `want` loads it; it stays while it's open (`item.open`, for one that opens itself, like the welcome tour
// or the screenshot editor), and lets go 20 s after it closes (time for its close animation, and a quick
// reopen is instant).
LazyLoader {
    id: root

    property bool want: false
    readonly property bool busy: want || (item?.open ?? false)
    onBusyChanged: if (!busy)
        linger.restart()
    active: busy || linger.running

    property Timer linger: Timer {
        interval: 20000
    }
}

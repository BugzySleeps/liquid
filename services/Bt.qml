pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth through BlueZ (Quickshell.Bluetooth). Without bluetoothd running there's no adapter, and the
// control centre says how to start it.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.name || d.deviceName)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (b.batteryAvailable - a.batteryAvailable) || String(a.name).localeCompare(String(b.name)))
    readonly property var connected: devices.filter(d => d.connected)
    readonly property string status: !available ? "no service" : !enabled ? "off" : connected.length === 1 ? connected[0].name : connected.length ? connected.length + " connected" : "on"
    readonly property string icon: !enabled ? "󰂲" : connected.length ? "󰂱" : "󰂯"

    function toggle() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function scan(on) {
        if (adapter && (adapter.enabled || !on))
            adapter.discovering = on;
    }

    // connected: disconnect · paired: connect · new: pair (trusted, so it reconnects), then connect
    property var pairing: null
    function use(d) {
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            d.connect();
        } else {
            pairing = d;
            d.trusted = true;
            d.pair();
        }
    }
    Connections {
        target: root.pairing
        function onPairedChanged() {
            if (root.pairing?.paired) {
                root.pairing.connect();
                root.pairing = null;
            }
        }
    }

    // BlueZ's icon names, as glyphs
    function glyph(d) {
        const i = String(d.icon);
        return i.includes("headset") || i.includes("headphone") ? "󰋋" : i.includes("audio") ? "󰓃" : i.includes("phone") ? "󰏲"
            : i.includes("mouse") ? "󰍽" : i.includes("keyboard") ? "󰌌" : i.includes("gaming") ? "󰖺" : i.includes("computer") ? "󰟀" : "󰂯";
    }
}

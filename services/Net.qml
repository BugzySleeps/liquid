pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wifi state through NetworkManager (Quickshell.Networking).
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var active: wifiDevice?.networks.values.find(n => n.connected) ?? null

    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool connected: !!active || !!wired
    readonly property real strength: active?.signalStrength ?? 0
    readonly property string name: active ? active.name : wired ? "wired" : enabled ? "offline" : "wifi off"
    readonly property string icon: {
        if (wired && !active)
            return "󰈀";
        if (!enabled || !active)
            return "󰤭";
        return ["󰤟", "󰤢", "󰤥", "󰤨"][Math.max(0, Math.min(3, Math.floor(strength * 4)))];
    }

    function toggle() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}

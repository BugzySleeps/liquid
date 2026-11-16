pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wifi through NetworkManager (Quickshell.Networking): its state, and the network list in the control centre.
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

    // every network in range: the connected one, then saved ones, then by signal
    readonly property var networks: wifiDevice ? wifiDevice.networks.values.filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []

    function scan(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }

    function secured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }
    function enterprise(n) {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.Leap, WifiSecurityType.DynamicWep].includes(n.security);
    }
    function bars(n) {
        return ["󰤟", "󰤢", "󰤥", "󰤨"][Math.max(0, Math.min(3, Math.floor(n.signalStrength * 4)))];
    }

    // connected: disconnect · saved or open: connect · locked: ask for the password (`asking`)
    property string asking: ""
    function use(n) {
        if (n.connected)
            n.disconnect();
        else if (n.known || !secured(n))
            n.connect();
        else
            asking = asking === n.name ? "" : n.name;
    }
    function join(n, password) {
        asking = "";
        n.connectWithPsk(password);
    }
}

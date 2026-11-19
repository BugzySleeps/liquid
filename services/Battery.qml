pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The laptop battery, through UPower's display device (all batteries combined). `present` is false on a desktop,
// and the bar leaves the battery out.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: !!dev && dev.ready && dev.isLaptopBattery
    // UPower reports 0–100, Quickshell 0–1, depending on the version: take either
    readonly property real level: !dev ? 0 : Math.max(0, Math.min(1, dev.percentage > 1 ? dev.percentage / 100 : dev.percentage))
    readonly property int pct: Math.round(level * 100)
    readonly property bool charging: !!dev && dev.state === UPowerDeviceState.Charging
    readonly property bool full: !!dev && (dev.state === UPowerDeviceState.FullyCharged || (!UPower.onBattery && pct >= 99))
    readonly property bool plugged: !UPower.onBattery
    readonly property bool low: !plugged && pct <= 15

    readonly property var empty: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    readonly property var filling: ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    readonly property string icon: full ? "󰂄" : (charging ? filling : empty)[Math.round(level * 10)]

    function span(s) {
        if (!s || s <= 0)
            return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }
    readonly property string status: full ? "full" : charging ? (span(dev.timeToFull) ? span(dev.timeToFull) + " to full" : "charging") : plugged ? "plugged in" : (span(dev.timeToEmpty) ? span(dev.timeToEmpty) + " left" : "on battery")
}

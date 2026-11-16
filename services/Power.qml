pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Power profiles through power-profiles-daemon (Quickshell's PowerProfiles). `available` is false until it's
// installed and running, and the control centre says so.
Singleton {
    id: root

    property bool available: false
    readonly property var names: ["saver", "balanced", "performance"]
    readonly property var icons: ["󰾆", "󰾅", "󰓅"]
    readonly property int profile: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : PowerProfiles.profile === PowerProfile.Performance ? 2 : 1
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function set(i) {
        PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][i];
    }

    // is the daemon on the system bus (running, or started on demand)?
    function check() {
        probe.running = true;
    }
    Component.onCompleted: check()
    Process {
        id: probe
        command: ["sh", "-c", "busctl --system list --no-pager 2>/dev/null | grep -qE '^(net.hadess|org.freedesktop.UPower).PowerProfiles '"]
        onExited: code => root.available = code === 0
    }
}

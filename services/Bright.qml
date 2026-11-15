pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness from sysfs (polled, so brightness keys show up too); set through brightnessctl.
Singleton {
    id: root

    property string device: ""
    property real value: 0
    readonly property bool available: device !== ""
    property int _max: 1

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    FileView {
        id: maxFile
        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        blockLoading: true
        onLoaded: root._max = Math.max(1, parseInt(text()) || 1)
    }

    FileView {
        id: curFile
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        blockLoading: true
    }

    Timer {
        running: root.available
        interval: 400
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            curFile.reload();
            const v = (parseInt(curFile.text()) || 0) / root._max;
            if (Math.abs(v - root.value) > 0.004)
                root.value = v;
        }
    }

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }
}

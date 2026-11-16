pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The idle tide (lock/IdleTide.qml draws it): after Settings.idleAfter minutes without a key or the mouse, the
// lock screen's liquid starts rising up over your windows, taking Settings.tideRise seconds to fill the screen.
// Touch anything and it drains away; let it fill and it becomes the lock screen. Anything holding the screen
// awake (a playing video, an idle inhibitor) holds the tide back too.
//   qs -c ekitai ipc call tide preview          a quick one (8 s) that opens the lock preview instead of locking
Singleton {
    id: root

    property real level: 0                       // 0 … 1.04 (over the top)
    property string phase: ""                    // "" · "rising" · "falling"
    property bool preview: false
    property int kick: 0                         // bumped as you come back: each screen drops a ripple
    readonly property bool shown: phase !== "" || level > 0

    // (Quickshell only takes a new timeout as the monitor's switched on, so a change switches it off and on)
    property bool restarting: false
    IdleMonitor {
        enabled: Settings.idleTide && !Lock.shown && !root.restarting
        timeout: Settings.idleAfter * 60
        respectInhibitors: true
        onTimeoutChanged: {
            root.restarting = true;
            root.restarting = false;
        }
        onIsIdleChanged: isIdle ? root.rise(false) : root.recede()
    }

    function rise(quick) {
        if (Lock.shown || phase === "rising")
            return;
        preview = quick;
        falling.stop();
        rising.duration = (quick ? 8 : Settings.tideRise) * 1000 * (1.04 - level) / 1.04;
        phase = "rising";
        rising.start();
    }

    function recede() {
        if (phase !== "rising")
            return;
        rising.stop();
        phase = "falling";
        kick++;
        if (level > 0.03)
            Sounds.lock("drain");
        falling.start();
    }

    NumberAnimation {
        id: rising
        target: root
        property: "level"
        to: 1.04
        easing.type: Easing.InQuad               // creeping at first, then faster: there's time to notice it
        onFinished: {
            if (root.phase !== "rising")
                return;
            if (root.preview)
                Lock.openPreview(false, true);
            else
                Lock.lock(false, true);          // full: it's the lock screen now (which starts full)
        }
    }
    NumberAnimation {
        id: falling
        target: root
        property: "level"
        to: 0
        duration: 950                            // the drain sound's length
        easing.type: Easing.InCubic
        onFinished: root.phase = ""
    }

    // locked (by the tide or anything else): the tide's under the lock screen now, so it can go
    Connections {
        target: Lock
        function onShownChanged() {
            if (!Lock.shown)
                return;
            rising.stop();
            falling.stop();
            root.phase = "";
            root.level = 0;
        }
    }

    IpcHandler {
        target: "tide"
        function preview(): void {
            root.rise(true);
        }
    }
}

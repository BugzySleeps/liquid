pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Whether the screen is being shared or recorded right now, so widgets can keep private things (where you
// are) off it. Sharing = a screencast through Hyprland (Discord, OBS, a browser sharing your screen), or the
// bar's own recorder (wl-screenrec, which Hyprland doesn't announce).
Singleton {
    id: root

    property bool casting: false
    readonly property bool sharing: casting || Recorder.on

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "screencast")         // "screencast>>1,0": on/off, then what's shared
                root.casting = String(e.data).split(",")[0] === "1";
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// cava's raw output as an array of 0..1 bar heights. Only runs while something is playing.
Singleton {
    id: root

    readonly property int bars: 30
    property var values: []

    readonly property string config: [
        "[general]",
        "bars = " + bars,
        "framerate = 30",
        "[input]",
        "method = pipewire",
        "source = auto",
        "[output]",
        "method = raw",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = 100",
        "[smoothing]",
        "noise_reduction = 60"
    ].join("\n")

    Process {
        running: Media.playing && !Perf.low       // performance mode: off
        command: ["sh", "-c", "f=\"$XDG_RUNTIME_DIR/ekitai-cava.conf\"; printf '%s\\n' \"$1\" > \"$f\" && exec ~/.config/rice/cava-run \"$f\"", "sh", root.config]
        stdout: SplitParser {
            onRead: line => root.values = line.split(";").filter(v => v !== "").map(v => Number(v) / 100)
        }
        onRunningChanged: if (!running)
            root.values = []
    }
}

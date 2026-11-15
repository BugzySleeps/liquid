pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screen recorder's state (~/.config/waybar/scripts/record.sh, wl-screenrec): the bar's button shows it,
// and Privacy uses it. The script's status loop prints a line whenever it changes (every second while
// recording).
Singleton {
    id: root

    property bool on: false
    property string time: ""

    function run(what) {                         // toggle · region · folder
        Quickshell.execDetached(["sh", "-c", "~/.config/waybar/scripts/record.sh " + what]);
    }

    Process {
        running: true
        command: ["sh", "-c", "exec ~/.config/waybar/scripts/record.sh status"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    root.on = d.class === "recording";
                    root.time = (d.text.match(/\d+:\d+/) ?? [""])[0];
                } catch (e) {}
            }
        }
    }
}

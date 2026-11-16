pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which panel is open, the launcher, the bar, do-not-disturb, plus the `qs ipc` entry points:
//   qs -c ekitai ipc call bar toggle
//   qs -c ekitai ipc call launcher toggle
//   qs -c ekitai ipc call launcher open ":"       opens it with text typed in (":" emoji, "/" files, "#" colours…)
//   qs -c ekitai ipc call panel toggle control|media|calendar
//   qs -c ekitai ipc call panel expand wifi|bt|night   the control centre, with those details open
//   qs -c ekitai ipc call dnd toggle
//   qs -c ekitai ipc call wall toggle            the wallpaper picker (picker/WallPicker.qml)
//   qs -c ekitai ipc call overview toggle        every workspace at once (switcher/Overview.qml)
Singleton {
    id: root

    property string panel: ""
    property string quick: ""                    // the control centre's open details: "" · wifi · bt · night
    property bool launcher: false
    property string launcherText: ""           // what the launcher opens with (`launcher open ":"`)
    property bool picker: false
    property bool overview: false                // switcher/Overview.qml
    property bool barVisible: true
    property bool dnd: false

    // the bar windows, so a panel's focus grab doesn't close it when the bar itself is clicked
    property list<QtObject> bars: []

    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    property string _closed: ""
    property real _closedAt: 0

    function toggle(name) {
        if (panel === name) {
            panel = "";
            return;
        }
        // a click outside closed this panel a moment ago; that same click shouldn't reopen it
        if (panel === "" && _closed === name && Date.now() - _closedAt < 300)
            return;
        launcher = false;
        panel = name;
    }

    function grabCleared(name) {
        if (panel !== name)
            return;
        _closed = name;
        _closedAt = Date.now();
        panel = "";
    }

    function openLauncher() {
        panel = "";
        picker = false;
        launcher = true;
    }

    function openPicker() {
        panel = "";
        launcher = false;
        picker = true;
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.launcher)
                root.launcher = false;
            else
                root.openLauncher();
        }
        function open(text: string): void {
            root.launcher = false;
            root.launcherText = text;
            root.openLauncher();
        }
    }

    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            root.toggle(name);
        }
        function close(): void {
            root.panel = "";
        }
        function expand(what: string): void {
            root.panel = "control";
            root.quick = what;
        }
    }

    IpcHandler {
        target: "dnd"
        function toggle(): void {
            root.dnd = !root.dnd;
        }
    }
}

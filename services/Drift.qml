pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The desktop widgets in the scrolling layout's endless row (Settings.canvasWidgets): so they don't sit stuck to
// the glass while the windows slide by, they move with the row too. "parallax": a far-off layer, drifting at a
// third of the windows' pace · "canvas": on the row itself, scrolling away with the windows · "pinned": still.
// While you're editing them they're back where they were placed, so dragging works as usual.
Singleton {
    id: root

    readonly property real pace: Settings.canvasWidgets === "canvas" ? 1 : Settings.canvasWidgets === "parallax" ? 0.3 : 0

    // how far along its row the workspace in front has scrolled: how far its leftmost column sits past where the
    // row starts (a gap in from the screen's edge)
    property real scroll: 0
    property bool jump: false                    // a new workspace: there at once, no slide
    property real shift: Widgets.editing ? 0 : -scroll * pace
    Behavior on shift {
        enabled: !root.jump
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutQuint
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.jump = true;
            look.restart();
        }
        function onRawEvent(e) {
            if (/^(activewindow|movewindow|openwindow|closewindow|resizewindow|changefloatingmode|configreloaded|fullscreen)/.test(e.name))
                look.restart();
        }
    }
    Component.onCompleted: look.restart()

    Timer {
        id: look
        interval: 50
        onTriggered: if (root.pace > 0 || root.scroll !== 0)
            clients.running = true
    }
    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ws = Hyprland.focusedWorkspace?.id;
                    const mx = Hyprland.focusedMonitor?.lastIpcObject?.x ?? 0;
                    const xs = JSON.parse(text).filter(c => c.workspace?.id === ws && !c.floating && !c.fullscreen && c.mapped !== false).map(c => c.at[0] - mx);
                    root.scroll = xs.length ? Math.max(0, 18 - Math.min(...xs)) : 0;
                } catch (e) {}
                root.jump = false;
            }
        }
    }
    // a mode turned on: catch up
    onPaceChanged: look.restart()
}

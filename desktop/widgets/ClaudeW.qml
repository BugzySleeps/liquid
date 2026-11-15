import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Claude Code's token usage (~/.config/rice/claude-usage reads its session logs, once a minute):
// the current 5-hour window and how long until it resets, today's total and what it's made of,
// and the last 12 hours as bars.
Item {
    id: root
    property var wd

    property var u: null
    property real now: Date.now() / 1000

    function fmt(n) {
        n = n || 0;
        return n >= 1e9 ? (n / 1e9).toFixed(1) + "B" : n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? Math.round(n / 1e3) + "k" : String(n);
    }
    function untilReset(s) {
        s = Math.max(0, Math.round(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        return h ? h + "h " + m + "m" : m + "m";
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "~/.config/rice/claude-usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.u = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Timer {
        running: root.visible
        interval: 60000
        repeat: true
        onTriggered: {
            root.now = Date.now() / 1000;
            reader.running = true;
        }
    }

    readonly property var win: u?.window ?? null
    readonly property real progress: win?.active ? Math.max(0, Math.min(1, (now - win.start) / (win.end - win.start))) : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ✻ claude                         opus 5.5
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Txt {
                text: "✻"
                font.pixelSize: Style.px(22)
                color: Colors.accent
            }
            Txt {
                Layout.fillWidth: true
                text: root.wd?.frame ? "" : "claude"     // a boxed widget has it on its border already
                color: Colors.bright
            }
            Txt {
                text: (root.u?.model ?? "").replace(/^claude-/, "").replace(/-(\d+)-(\d+)$/, " $1.$2")
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }

        // the window: tokens so far, and when it resets
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Txt {
                text: root.win?.active ? root.fmt(root.win.tokens) : "idle"
                font.pixelSize: Style.px(33)
                color: Colors.bright
            }
            Column {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    text: root.win?.active ? "this 5h window" : "no window open"
                    font.pixelSize: Style.small
                    color: Colors.mid
                }
                Txt {
                    text: root.win?.active ? "resets in " + root.untilReset(root.win.end - root.now) : "starts with your next message"
                    font.pixelSize: Style.small
                    color: Colors.accent
                }
            }
        }
        // how far through the window
        Meter {
            Layout.fillWidth: true
            segments: 30
            segWidth: Math.max(2, Math.floor((width - 29 * 2) / 30))
            segHeight: 5
            value: root.progress
        }

        // today
        Txt {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: "today " + root.fmt(root.u?.today.tokens) + " · " + (root.u?.today.sessions ?? 0) + " session" + ((root.u?.today.sessions ?? 0) === 1 ? "" : "s") + " · " + (root.u?.today.replies ?? 0) + " replies"
            font.pixelSize: Style.small
            color: Colors.accent
        }
        Txt {
            Layout.fillWidth: true
            text: "in " + root.fmt((root.u?.today.input ?? 0) + (root.u?.today.cacheWrite ?? 0)) + " · out " + root.fmt(root.u?.today.output) + " · cache " + root.fmt(root.u?.today.cacheRead)
            font.pixelSize: Style.small
            color: Colors.mid
        }

        // the last 12 hours
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 20
            readonly property var h: root.u?.hours ?? []
            readonly property real peak: Math.max(1, ...h)
            Row {
                anchors.bottom: parent.bottom
                spacing: 3
                Repeater {
                    model: parent.parent.h.length
                    Rectangle {
                        required property int index
                        readonly property real v: parent.parent.h[index] / parent.parent.peak
                        anchors.bottom: parent.bottom
                        width: (parent.parent.width - 3 * 11) / 12
                        height: v > 0 ? Math.max(2, v * parent.parent.height) : 1
                        radius: Look.round ? Math.min(width / 2, 3) : 0
                        color: index === 11 ? Colors.bright : v > 0 ? Colors.accent : Colors.faint
                        opacity: v > 0 ? 0.55 + 0.45 * v : 1
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Txt {
                Layout.fillWidth: true
                text: "12h ago"
                font.pixelSize: Style.small
                color: Colors.dim
            }
            Txt {
                text: "now"
                font.pixelSize: Style.small
                color: Colors.dim
            }
        }
    }
}

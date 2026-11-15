import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// cmus's library and queue, in the music panel. Click a song to play it now, right-click to queue it.
// The song list comes from ~/.config/rice/music-lib (tags read once and cached).
Item {
    id: root

    property string tab: "library"               // library | queue
    property var songs: []
    property string playing: ""                  // the file cmus is playing

    function refresh() {
        loader.command = ["sh", "-c", "~/.config/rice/music-lib " + tab];
        loader.running = true;
        nowFile.running = true;
    }
    onVisibleChanged: if (visible)
        refresh()
    onTabChanged: refresh()
    Connections {
        target: Media
        function onTitleChanged() {
            if (root.visible)
                nowFile.running = true;
        }
    }

    Process {
        id: loader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.songs = JSON.parse(text);
                } catch (e) {
                    root.songs = [];
                }
            }
        }
    }
    Process {
        id: nowFile
        command: ["sh", "-c", "cmus-remote -Q 2>/dev/null | sed -n 's/^file //p'"]
        stdout: StdioCollector {
            onStreamFinished: root.playing = text.trim()
        }
    }

    function play(s) {
        Quickshell.execDetached(["cmus-remote", "-f", s.path]);
        root.playing = s.path;
    }
    function enqueue(s) {
        Quickshell.execDetached(["cmus-remote", "-q", s.path]);
        queued.text = "󰐕 queued " + s.title;
        queued.opacity = 1;
        fadeQueued.restart();
        if (tab === "queue")
            refreshLater.restart();
    }
    Timer {
        id: refreshLater
        interval: 250
        onTriggered: root.refresh()
    }

    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        return q ? songs.filter(s => (s.title + " " + s.artist + " " + s.album).toLowerCase().includes(q)) : songs;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Chip {
                text: "󰲸 library"
                on: root.tab === "library"
                onClicked: root.tab = "library"
            }
            Chip {
                text: "󰐑 queue"
                on: root.tab === "queue"
                onClicked: root.tab = "queue"
            }
            Field {
                id: search
                visible: root.tab === "library"
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: "search " + root.songs.length + " songs"
            }
            Item {
                visible: root.tab === "queue"
                Layout.fillWidth: true
            }
            Chip {
                visible: root.tab === "queue" && root.songs.length > 0
                text: "clear"
                onClicked: {
                    Quickshell.execDetached(["cmus-remote", "-q", "-c"]);
                    refreshLater.restart();
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool now: modelData.path === root.playing
                width: list.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: Look.round ? 8 : 0
                    color: row.now ? Qt.alpha(Colors.accent, 0.18) : area.containsMouse ? Colors.bg2 : "transparent"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Icon {
                        Layout.preferredWidth: 14
                        text: row.now ? (Media.playing ? "󰐊" : "󰏤") : root.tab === "queue" ? String(row.index + 1) : "󰝚"
                        font.pixelSize: row.now ? 12 : 11
                        color: row.now ? Colors.bright : Colors.dim
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        font.bold: row.now
                        color: row.now ? Colors.bright : Colors.accent
                    }
                    Txt {
                        Layout.preferredWidth: list.width * 0.36
                        text: [row.modelData.artist, row.modelData.album].filter(x => x).join("  ·  ")
                        font.pixelSize: Style.small
                        color: Colors.mid
                    }
                    Txt {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Media.time(row.modelData.length)
                        font.pixelSize: Style.small
                        color: Colors.dim
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => e.button === Qt.RightButton ? root.enqueue(row.modelData) : root.play(row.modelData)
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.tab === "queue" ? "the queue's empty  ·  right-click a song in the library to queue it" : root.songs.length ? "nothing matches" : "loading…"
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }

        Txt {
            id: queued
            Layout.fillWidth: true
            text: "click: play now  ·  right-click: add to the queue"
            font.pixelSize: Style.small
            color: Colors.dim
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.slow
                }
            }
            Timer {
                id: fadeQueued
                interval: 1800
                onTriggered: queued.text = "click: play now  ·  right-click: add to the queue"
            }
        }
    }
}

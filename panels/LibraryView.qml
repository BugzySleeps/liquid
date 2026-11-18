import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// cmus's library, queue and playlists, in the music panel. Click a song to play it now, right-click to queue it.
// The files tab lists everything in ~/Music: click songs to pick them, then save them as a new cmus playlist or
// add them to one you already have ("add to…", or "add songs" on an open playlist).
// The song lists come from ~/.config/rice/music-lib (tags read once and cached). Playlists are read from
// cmus's playlist files, which cmus writes when it quits.
Item {
    id: root

    property string tab: "library"               // library | queue | playlists | files
    property string playlist: ""                 // the open playlist, on the playlists tab ("" = the list of them)
    property var songs: []
    property var playlists: []                   // [{ name, count }]
    property var picked: []                      // files tab: the songs picked for a new playlist, in the order picked
    property string target: ""                   // files tab: the playlist picked songs go into ("" = a new one)
    property bool choosing: false                // files tab: showing the existing playlists to add to
    property string playing: ""                  // the file cmus is playing
    readonly property bool picking: tab === "playlists" && playlist === ""
    readonly property string hint: picking ? "click a playlist to open it" : tab === "files" ? "click songs to pick them  ·  right-click: add to the queue" : "click: play now  ·  right-click: add to the queue"
    readonly property bool searchable: tab === "library" || tab === "files" || (tab === "playlists" && playlist !== "")

    // what to ask music-lib for. From tab and playlist themselves, not `picking`: in their change handlers a
    // binding on them may not have caught up yet (it asked for the last view's list)
    function want() {
        return tab !== "playlists" ? [tab] : playlist === "" ? ["playlists"] : ["playlist", playlist];
    }
    // every refresh runs a music-lib of its own (job, below), its answer labelled with what it was asked for, so
    // switching views mid-load can't show one view's list in another or lose an answer; `loading` until the
    // answer for what's on screen is in
    property string wanted: ""                   // what's on screen (want(), as text)
    property string loaded: ""                   // the last answer that was for it
    readonly property bool loading: wanted !== loaded
    function refresh() {
        nowFile.running = true;
        wanted = JSON.stringify(want());
        const p = job.createObject(root, { key: wanted, command: ["sh", "-c", '~/.config/rice/music-lib "$@"', "music-lib"].concat(want()) });
        p.running = true;
    }
    function answer(key, text) {
        if (key !== JSON.stringify(want()))
            return;                              // for a view that's gone
        let data = [];
        try {
            data = JSON.parse(text);
        } catch (e) {}
        if (!Array.isArray(data))
            data = [];
        if (JSON.parse(key)[0] === "playlists")
            playlists = data;
        else
            songs = data;
        loaded = key;
    }
    Component {
        id: job
        Process {
            id: proc
            property string key
            stdout: StdioCollector {
                onStreamFinished: {
                    root.answer(proc.key, text);
                    Qt.callLater(proc.destroy);
                }
            }
        }
    }
    onVisibleChanged: if (visible)
        refresh()
    onTabChanged: {
        playlist = "";
        picked = [];
        plName.text = "";
        target = "";
        choosing = false;
        if (tab === "files")
            listLoader.running = true;
        songs = [];
        search.text = "";
        refresh();
    }
    onPlaylistChanged: {
        songs = [];
        playlists = [];
        search.text = "";
        refresh();
    }
    Connections {
        target: Media
        function onTitleChanged() {
            if (root.visible)
                nowFile.running = true;
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
        flash("󰐕 queued " + s.title);
        if (tab === "queue")
            refreshLater.restart();
    }
    function flash(msg) {
        queued.text = msg;
        queued.opacity = 1;
        fadeQueued.restart();
    }
    // play the whole open playlist: the queue is replaced by its songs
    function playAll() {
        const paths = songs.map(s => s.path);
        if (!paths.length)
            return;
        Quickshell.execDetached(["sh", "-c", 'cmus-remote -q -c; cmus-remote -f "$1"; shift; [ $# -gt 0 ] && cmus-remote -q "$@"', "play"].concat(paths));
        root.playing = paths[0];
        flash("󰐊 playing " + playlist);
    }
    function queueAll() {
        const paths = songs.map(s => s.path);
        if (!paths.length)
            return;
        Quickshell.execDetached(["cmus-remote", "-q"].concat(paths));
        flash("󰐕 queued " + paths.length + " songs from " + playlist);
    }
    function togglePick(s) {
        const i = picked.indexOf(s.path);
        picked = i < 0 ? picked.concat([s.path]) : picked.filter(p => p !== s.path);
    }
    function pickAll() {
        const all = shown.map(s => s.path);
        picked = picked.length === all.length ? [] : picked.concat(all.filter(p => !picked.includes(p)));
    }
    // mode: "create" (a new playlist called name, or an automatic name) | "add" (to the playlist called name)
    function savePicked(mode, name) {
        if (!picked.length || creator.running)
            return;
        creator.command = ["sh", "-c", '~/.config/rice/music-lib "$@"', "music-lib", mode, name].concat(picked);
        creator.running = true;
    }
    // jump from an open playlist to the files tab to pick songs for it
    function addSongsTo(name) {
        tab = "files";
        target = name;
    }
    Process {
        id: listLoader
        command: ["sh", "-c", "~/.config/rice/music-lib playlists"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.playlists = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Process {
        id: creator
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {}
                if (!r.ok) {
                    root.flash("󰀦 " + (r.error || "couldn't save the playlist"));
                    return;
                }
                root.tab = "playlists";      // show the new playlist
                root.playlist = r.name;
                root.flash("󰄬 " + r.msg);
            }
        }
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
            Chip {
                text: "󰲹 playlists"
                on: root.tab === "playlists"
                onClicked: root.tab === "playlists" ? root.playlist = "" : root.tab = "playlists"
            }
            Chip {
                text: "󰉋 files"
                on: root.tab === "files"
                onClicked: root.tab = "files"
            }
            Field {
                id: search
                visible: root.searchable
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: "search " + root.songs.length + " songs"
            }
            Item {
                visible: !root.searchable
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

        RowLayout {
            visible: root.tab === "playlists" && root.playlist !== ""
            Layout.fillWidth: true
            spacing: 4
            Chip {
                text: "󰁍"
                onClicked: root.playlist = ""
            }
            Txt {
                Layout.fillWidth: true
                text: root.playlist + "  ·  " + root.songs.length + " songs"
                font.bold: true
                color: Colors.bright
            }
            Chip {
                visible: root.songs.length > 0
                text: "󰐊 play all"
                onClicked: root.playAll()
            }
            Chip {
                visible: root.songs.length > 0
                text: "󰐕 queue all"
                onClicked: root.queueAll()
            }
            Chip {
                text: "󰉋 add songs"
                onClicked: root.addSongsTo(root.playlist)
            }
        }

        ListView {
            id: picker
            visible: root.picking
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.playlists
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1

            delegate: Item {
                id: prow
                required property var modelData
                width: picker.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: Look.round ? 8 : 0
                    color: parea.containsMouse ? Colors.bg2 : "transparent"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Icon {
                        Layout.preferredWidth: 14
                        text: "󰲸"
                        font.pixelSize: 11
                        color: Colors.dim
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: prow.modelData.name
                        color: Colors.accent
                    }
                    Txt {
                        text: prow.modelData.count + (prow.modelData.count === 1 ? " song" : " songs")
                        font.pixelSize: Style.small
                        color: Colors.dim
                    }
                }
                MouseArea {
                    id: parea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playlist = prow.modelData.name
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: picker.count === 0
                text: root.loading ? "loading…" : "no playlists yet  ·  make one in the files tab"
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }

        ListView {
            id: list
            visible: !root.picking
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
                readonly property int pick: root.tab === "files" ? root.picked.indexOf(modelData.path) : -1
                width: list.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: Look.round ? 8 : 0
                    color: row.pick >= 0 ? Qt.alpha(Colors.accent, 0.18) : row.now && root.tab !== "files" ? Qt.alpha(Colors.accent, 0.18) : area.containsMouse ? Colors.bg2 : "transparent"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Icon {
                        visible: root.tab !== "files"
                        Layout.preferredWidth: 14
                        text: row.now ? (Media.playing ? "󰐊" : "󰏤") : root.tab === "queue" ? String(row.index + 1) : "󰝚"
                        font.pixelSize: row.now ? 12 : 11
                        color: row.now ? Colors.bright : Colors.dim
                    }
                    // files tab: a tick box, numbered in the order the songs were picked
                    Rectangle {
                        visible: root.tab === "files"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: Look.round ? 8 : 2
                        color: row.pick >= 0 ? Colors.accent : "transparent"
                        border.width: row.pick >= 0 ? 0 : 1
                        border.color: Colors.dim
                        Txt {
                            anchors.centerIn: parent
                            visible: row.pick >= 0
                            text: row.pick + 1
                            font.pixelSize: 9
                            font.bold: true
                            color: Colors.bg
                        }
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
                    onClicked: e => e.button === Qt.RightButton ? root.enqueue(row.modelData) : root.tab === "files" ? root.togglePick(row.modelData) : root.play(row.modelData)
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.loading ? "loading…" : root.songs.length ? "nothing matches" : root.tab === "queue" ? "the queue's empty  ·  right-click a song in the library to queue it" : root.tab === "files" ? "no music in ~/Music" : root.tab === "library" ? "cmus's library is empty (is cmus running?)" : "this playlist's empty"
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }

        // files tab: the playlists you can add the picked songs to
        Flow {
            visible: root.tab === "files" && root.choosing && root.target === ""
            Layout.fillWidth: true
            spacing: 4
            Txt {
                height: 22
                verticalAlignment: Text.AlignVCenter
                text: root.playlists.length ? "add " + root.picked.length + " to:" : "no playlists yet  ·  save a new one instead"
                font.pixelSize: Style.small
                color: Colors.mid
            }
            Repeater {
                model: root.playlists
                Chip {
                    required property var modelData
                    text: "󰲸 " + modelData.name
                    opacity: root.picked.length ? 1 : 0.5
                    onClicked: root.savePicked("add", modelData.name)
                }
            }
        }

        RowLayout {
            visible: root.tab === "files"
            Layout.fillWidth: true
            spacing: 4
            Chip {
                text: root.picked.length && root.picked.length === root.shown.length ? "󰒆 none" : "󰒆 all"
                onClicked: root.pickAll()
            }
            // adding to a playlist picked from its "add songs" button
            Txt {
                visible: root.target !== ""
                Layout.fillWidth: true
                text: "adding to " + root.target
                font.bold: true
                color: Colors.bright
            }
            Chip {
                visible: root.target !== ""
                text: root.picked.length ? "󰐕 add · " + root.picked.length : "󰐕 add"
                on: root.picked.length > 0
                opacity: root.picked.length ? 1 : 0.5
                onClicked: root.savePicked("add", root.target)
            }
            Chip {
                visible: root.target !== ""
                text: "󰅖"
                onClicked: root.target = ""
            }
            // or a new playlist / one picked from "add to…"
            Field {
                id: plName
                visible: root.target === ""
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: root.picked.length ? "name it (or leave blank)" : "pick some songs above"
            }
            Chip {
                visible: root.target === ""
                text: root.picked.length ? "󰐕 new playlist · " + root.picked.length : "󰐕 new playlist"
                on: root.picked.length > 0
                opacity: root.picked.length ? 1 : 0.5
                onClicked: root.savePicked("create", plName.text)
            }
            Chip {
                visible: root.target === ""
                text: "󰲸 add to…"
                on: root.choosing
                onClicked: root.choosing = !root.choosing
            }
        }

        Txt {
            id: queued
            Layout.fillWidth: true
            text: root.hint
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
                onTriggered: queued.text = Qt.binding(() => root.hint)
            }
        }
    }
}

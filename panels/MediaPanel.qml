import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config
import qs.services
import qs.components

// The music panel (click the song in the bar): the cover blurred into the whole panel, the art, a
// waterline visualizer, synced lyrics scrolling past (or the equaliser), a seek bar, controls, where
// the sound goes, and lyrics / eq / shuffle / repeat.
Panel {
    id: root
    name: "media"
    side: "center"
    panelWidth: 660
    title: "NOW PLAYING"

    property bool showLyrics: true
    property bool showEq: false
    property bool showLib: false
    //   qs -c ekitai ipc call music eq       open the panel on the equaliser (again: back to lyrics)
    IpcHandler {
        target: "music"
        function library(): void {
            root.showLib = Ui.panel === "media" ? !root.showLib : true;
            root.showEq = false;
            Ui.panel = "media";
        }
        function eq(): void {
            root.showEq = Ui.panel === "media" ? !root.showEq : true;
            root.showLib = false;
            Ui.panel = "media";
        }
    }
    readonly property var player: Media.player
    readonly property bool empty: !player?.trackTitle      // nothing loaded: one quiet state, not placeholders

    // ── the cover, blurred and tinted, under everything ──
    backdrop: Component {
        Item {
            Image {
                id: cover
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 320
                asynchronous: true
                visible: false
            }
            FastBlur {
                id: blurred
                anchors.fill: parent
                source: cover
                radius: 64
                visible: false
            }
            Colorize {
                anchors.fill: parent
                source: blurred
                visible: cover.status === Image.Ready
                hue: Colors.accent.hslHue
                saturation: 0.6
                lightness: -0.35
                opacity: 0.55
            }
            Rectangle {                          // darker towards the bottom, where the controls are
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Colors.bg, 0.25)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Colors.bg, 0.75)
                    }
                }
            }
        }
    }

    // ── title ──
    RowLayout {
        width: parent.width
        spacing: 10
        Column {
            Layout.fillWidth: true
            spacing: 2
            Txt {
                width: parent.width
                text: root.empty ? "nothing playing" : root.player.trackTitle
                font.pixelSize: Style.px(Style.big)
                font.bold: true
                color: Colors.bright
            }
            Txt {
                width: parent.width
                visible: !root.empty
                text: [Media.artist, root.player?.trackAlbum].filter(s => s).join("  ·  ") || "—"
                color: Colors.accent
            }
        }
        Txt {
            text: Media.source.toLowerCase()
            font.pixelSize: Style.small
            font.letterSpacing: 1
            color: Colors.mid
        }
    }

    // ── nothing loaded: a way to start something ──
    Column {
        visible: root.empty && !root.showLib
        width: parent.width
        topPadding: 18
        bottomPadding: 18
        spacing: 14
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰝚"
            font.pixelSize: 40
            color: Colors.dim
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Chip {
                text: "󰝚 open cmus"
                onClicked: {
                    Ui.panel = "";
                    Quickshell.execDetached(["sh", "-c", "~/.config/waybar/scripts/cmus.sh toggle"]);
                }
            }
            Chip {
                text: "󰲸 pick a song"
                on: true
                onClicked: root.showLib = true
            }
        }
    }

    // ── art · waterline · lyrics ──
    RowLayout {
        visible: !root.empty || root.showLib
        width: parent.width
        height: root.showLib ? 290 : 168          // more room for the library
        Behavior on height {
            NumberAnimation {
                duration: Style.med
                easing.type: Easing.OutCubic
            }
        }
        spacing: 18

        Art {
            visible: !root.empty
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
            Layout.alignment: Qt.AlignVCenter
            source: Media.art
            sourceSize: 320
            borderColor: "transparent"
            turning: Media.playing
        }

        EqView {
            visible: root.showEq
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        LibraryView {
            visible: root.showLib
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Waterline {
            visible: !root.showEq && !root.showLib
            Layout.preferredWidth: 96
            Layout.fillHeight: true
            bars: 12
        }

        // lyrics: the current line in the middle, the rest fading away above and below
        Item {
            visible: !root.showEq && !root.showLib
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: lyricList
                anchors.fill: parent
                visible: root.showLyrics && Lyrics.lines.length > 0
                model: Lyrics.lines
                interactive: Lyrics.status === "plain"
                currentIndex: Lyrics.status === "synced" ? Math.max(0, Lyrics.index) : -1
                highlightRangeMode: Lyrics.status === "synced" ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: height / 2 - 20
                preferredHighlightEnd: height / 2 + 20
                highlightMoveDuration: 450
                spacing: 4
                delegate: Txt {
                    required property var modelData
                    required property int index
                    readonly property int away: Lyrics.status === "synced" ? Math.abs(index - Lyrics.index) : 1
                    width: lyricList.width
                    topPadding: away === 0 ? 4 : 3
                    bottomPadding: topPadding
                    text: modelData.text || "♪"
                    elide: Text.ElideRight
                    wrapMode: away === 0 ? Text.WordWrap : Text.NoWrap     // the current line can take two
                    maximumLineCount: away === 0 ? 2 : 1
                    font.pixelSize: Style.px(away === 0 ? 16 : 12)
                    font.bold: away === 0
                    color: away === 0 ? Colors.bright : Colors.accent
                    opacity: away === 0 ? 1 : Math.max(0.12, 0.65 - away * 0.2)
                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: Style.med
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.med
                        }
                    }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: !lyricList.visible
                spacing: 6
                Txt {
                    width: parent.width
                    text: root.player?.trackTitle || Media.title
                    font.pixelSize: Style.px(20)
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    color: Colors.bright
                }
                Txt {
                    width: parent.width
                    text: !root.showLyrics ? (Media.artist || "")
                        : Lyrics.status === "loading" ? "finding lyrics…"
                        : Lyrics.status === "offline" ? "lyrics need the internet"
                        : Media.active ? "no lyrics for this one" : "play something"
                    font.pixelSize: Style.small
                    color: Colors.mid
                }
            }
        }
    }

    // ── seek ──
    RowLayout {
        visible: !root.empty
        width: parent.width
        spacing: 10
        Txt {
            text: Media.time(Media.position)
            font.pixelSize: Style.small
            color: Colors.mid
        }
        SegSlider {
            Layout.fillWidth: true
            segments: 60
            value: Media.length > 0 ? Media.position / Media.length : 0
            onMoved: v => Media.seek(v)
        }
        Txt {
            text: Media.time(Media.length)
            font.pixelSize: Style.small
            color: Colors.mid
        }
    }

    // ── where the sound goes · controls · toggles ──
    // two equal sides keep the controls in the middle, and nothing can slide under them
    RowLayout {
        width: parent.width
        height: 48
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰋋"
                    color: Colors.mid
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    text: (Audio.sink?.description || Audio.sink?.nickname || "").toLowerCase()
                    font.pixelSize: Style.small
                    color: Colors.mid
                }
            }
        }

        Row {
            spacing: 14
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰒮"
                size: 34
                onClicked: Media.previous()
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: Media.playing ? "󰏤" : "󰐊"
                size: 48
                iconSize: 20
                armed: true
                spin: Look.wavy && Media.playing ? playSpin.angle : 0
                onClicked: Media.toggle()
                Item {
                    id: playSpin
                    property real angle: 0
                    NumberAnimation on angle {
                        running: Look.wavy && Media.playing && root.open
                        from: 0
                        to: 360
                        duration: 9000
                        loops: Animation.Infinite
                    }
                }
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰒭"
                size: 34
                onClicked: Media.next()
            }
        }

        // lyrics · library · art · eq · shuffle · repeat (icons; the one showing is filled)
        Item {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Chip {
                    text: "󰎈"
                    minWidth: 28
                    on: root.showLyrics && !root.showEq && !root.showLib
                    onClicked: {
                        root.showLyrics = root.showEq || root.showLib ? true : !root.showLyrics;
                        root.showEq = false;
                        root.showLib = false;
                    }
                }
                Chip {
                    text: "󰲸"
                    minWidth: 28
                    on: root.showLib
                    onClicked: {
                        root.showLib = !root.showLib;
                        root.showEq = false;
                    }
                }
                Chip {
                    text: "󰏘"
                    minWidth: 28
                    on: Settings.artAccent
                    onClicked: Settings.set("artAccent", !Settings.artAccent)
                }
                Chip {
                    text: Eq.on ? "󰺢·" : "󰺢"                // the dot: the eq is on
                    minWidth: 28
                    on: root.showEq
                    onClicked: {
                        root.showEq = !root.showEq;
                        root.showLib = false;
                    }
                }
                Chip {
                    visible: root.player?.shuffleSupported ?? false
                    text: "󰒝"
                    minWidth: 28
                    on: root.player?.shuffle ?? false
                    onClicked: root.player.shuffle = !root.player.shuffle
                }
                Chip {
                    visible: root.player?.loopSupported ?? false
                    text: root.player?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                    minWidth: 28
                    on: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components

// The middle of the bar, as a dynamic island. At rest: the clock, the song and cmus. When something
// happens it swells out of the bar like a drop stretching (spring physics: it overshoots and settles),
// shows it, then shrinks back:
//   volume / brightness → the icon, a level and the number      (Settings.osdStyle "island")
//   a new track         → the cover, the title and the artist    (Settings.islandTracks)
//   a notification      → the app and what it says               (Settings.islandNotifs; ones with
//                         buttons, or critical ones, still get the full popup)
//   Claude Code         → ✻ done, or ✻ needs you, and the project  (Settings.islandClaude; a Claude Code
//                         Stop / Notification hook calls config/rice/claude-island, which calls `claude` below)
// Its own window, sized for its biggest shape; the input region follows the island, so the rest of it
// lets clicks through.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            anchors.top: true
            margins.top: Style.gap
            implicitWidth: 520
            implicitHeight: 120
            // over the bar, not pushed below the space the bar reserves
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // shown a moment after the bar: they share a layer, and whichever appears last sits on top. Hide the
            // bar and bring it back, and the island would come back under it
            visible: Ui.barVisible && afterBar
            property bool afterBar: false
            Timer {
                running: Ui.barVisible
                interval: 120
                onTriggered: win.afterBar = true
            }
            Connections {
                target: Ui
                function onBarVisibleChanged() {
                    if (!Ui.barVisible)
                        win.afterBar = false;
                }
            }
            WlrLayershell.namespace: "ekitai-island"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region {
                item: island
            }

            Component.onCompleted: Ui.bars = [...Ui.bars, win]
            Component.onDestruction: Ui.bars = Ui.bars.filter(b => b !== win)

            // ── what it's showing ──
            property string mode: "rest"         // rest · level · track · notify · claude
            property string levelIcon: ""
            property real level: 0
            property var note: null
            property bool claudeNeeds: false     // waiting on you (a question, a permission) rather than done
            property string claudeProject: ""
            property string claudeText: ""
            property bool armed: false           // ignore the values settling as the shell starts

            function show(m, ms) {
                mode = m;
                back.interval = ms;
                back.restart();
            }
            Timer {
                interval: 1500
                running: true
                onTriggered: win.armed = true
            }
            Timer {
                id: back
                onTriggered: if (hover.containsMouse)
                    restart();
                else
                    win.mode = "rest"
            }

            Connections {
                target: Audio
                function onVolumeChanged() {
                    win.level_(Audio.icon, Audio.volume);
                }
                function onMutedChanged() {
                    win.level_(Audio.icon, Audio.muted ? 0 : Audio.volume);
                }
            }
            Connections {
                target: Bright
                function onValueChanged() {
                    win.level_("󰃟", Bright.value);
                }
            }
            function level_(icon, v) {
                if (!armed || Settings.osdStyle !== "island" || Ui.panel === "control")
                    return;
                levelIcon = icon;
                level = v;
                show("level", 1400);
                Sounds.play("tick");
            }

            Connections {
                target: Media
                function onTrackKeyChanged() {
                    if (win.armed && Settings.islandTracks && Media.player?.trackTitle && win.mode !== "notify")
                        trackLater.restart();
                }
            }
            Timer {
                id: trackLater                   // the title and art arrive in pieces: wait for them
                interval: 350
                onTriggered: win.show("track", 3500)
            }

            Connections {
                target: Notifs
                function onArrived(n) {
                    if (win.screen !== Ui.screen)
                        return;
                    win.note = n;
                    win.show("notify", 4500);
                }
            }

            //   qs -c ekitai ipc call island preview level|track|notify      (to see a shape)
            //   qs -c ekitai ipc call island claude done|needs <project> <text>
            IpcHandler {
                target: "island"
                function claude(kind: string, project: string, text: string): void {
                    if (win.screen !== Ui.screen || !Settings.islandClaude)
                        return;
                    win.claudeNeeds = kind === "needs";
                    win.claudeProject = project;
                    win.claudeText = text;
                    win.show("claude", win.claudeNeeds ? 8000 : 5000);
                    claudeMark.pop();
                    Sounds.play(win.claudeNeeds ? "drip" : "bubble");
                }
                function preview(mode: string): void {
                    if (win.screen !== Ui.screen || !["level", "track", "notify", "claude", "rest"].includes(mode))
                        return;
                    if (mode === "level") {
                        win.levelIcon = Audio.icon;
                        win.level = Audio.volume;
                    }
                    if (mode === "notify")
                        win.note = Notifs.history[0] ?? null;
                    win.show(mode, 3000);
                }
            }

            // ── the shapes ──
            readonly property real restW: rest.implicitWidth + 2
            readonly property var target: ({
                    rest: [restW, Style.barHeight],
                    level: [320, 42],
                    track: [380, 76],
                    notify: [400, 70],
                    claude: [340, 60]
                })[mode]

            Frame {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.target[0]
                height: win.target[1]
                // the stretch: springs, so it overshoots a little and settles, like a drop
                Behavior on width {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.28
                        epsilon: 0.5
                    }
                }
                Behavior on height {
                    SpringAnimation {
                        spring: 3.4
                        damping: 0.32
                        epsilon: 0.5
                    }
                }
                // in the strip it's part of the bar at rest, and only stands out when it swells
                readonly property bool flat: Settings.barStyle === "strip" && win.mode === "rest"
                color: flat ? "transparent" : Colors.glass
                border.width: flat ? 0 : Style.line
                border.color: win.mode === "rest" ? Colors.faint : Colors.dim
                clip: true

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton     // just watching: the island stays open while you look
                }

                // ── rest: the clock, the song, cmus ──
                Row {
                    id: rest
                    x: 1
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: win.mode === "rest" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.fast
                        }
                    }

                    // the clock: the hour big, the minutes and seconds stacked small beside it, then the date
                    Cell {
                        onClicked: Ui.toggle("calendar")
                        Txt {
                            text: Qt.formatDateTime(clock.date, "HH")
                            font.pixelSize: Style.px(22)
                            color: Colors.bright
                        }
                        Column {
                            spacing: -3
                            Txt {
                                text: Qt.formatDateTime(clock.date, "mm")
                                color: Colors.bright
                            }
                            Txt {
                                text: Qt.formatDateTime(clock.date, "ss")
                                color: Colors.dim
                            }
                        }
                        Txt {
                            Layout.leftMargin: 4
                            text: Qt.formatDateTime(clock.date, "ddd d").toLowerCase()
                            color: Colors.mid
                        }
                    }
                    Sep {
                        visible: Settings.barMedia && Media.active
                    }
                    Cell {
                        visible: Settings.barMedia && Media.active
                        onClicked: m => m.button === Qt.MiddleButton ? Media.toggle() : Ui.toggle("media")
                        onScrolled: d => d > 0 ? Media.previous() : Media.next()
                        Icon {
                            text: Media.playing ? "󰐊" : "󰏤"
                            font.pixelSize: 12
                        }
                        Visualizer {
                            visible: Media.playing
                            bars: 8
                            height: 12
                        }
                        Txt {
                            text: Media.line
                            Layout.maximumWidth: 220
                        }
                    }
                    Sep {}
                    // cmus: left = show/hide the popup (starts cmus), right = pop out as a window / dock back
                    Cell {
                        pad: 9
                        hint: "cmus"
                        onClicked: m => Quickshell.execDetached(["sh", "-c", "~/.config/waybar/scripts/cmus.sh " + (m.button === Qt.RightButton ? "detach" : "toggle")])
                        Icon {
                            text: "󰝚"
                            font.pixelSize: 14
                            color: Media.source.toLowerCase() === "cmus" ? Colors.accent : Colors.mid
                        }
                    }
                }

                // ── a level: volume or brightness ──
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    opacity: win.mode === "level" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.fast
                        }
                    }
                    Icon {
                        text: win.levelIcon
                        font.pixelSize: 18
                        color: Colors.bright
                    }
                    // the liquid from the old side vial, lying on its side: it fills left to right, and its
                    // surface (the edge on the right) sloshes when the level moves
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        Vial {
                            anchors.centerIn: parent
                            width: parent.height
                            height: parent.width
                            rotation: 90                  // its bottom to the left: it fills from the left
                            inset: 2
                            level: win.level
                            alive: win.mode === "level"
                            sloshScale: 0.35             // lying down, it's long and thin: a gentler slosh
                        }
                    }
                    Txt {
                        Layout.preferredWidth: 33
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(win.level * 100)
                        color: Colors.bright
                    }
                }

                // ── a new track ──
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    opacity: win.mode === "track" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.med
                        }
                    }
                    Art {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        source: Media.art
                        sourceSize: 120
                        borderColor: "transparent"
                        turning: Media.playing
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Txt {
                            width: parent.width
                            text: "now playing"
                            font.pixelSize: Style.small
                            font.letterSpacing: 1
                            color: Colors.mid
                        }
                        Txt {
                            width: parent.width
                            text: Media.player?.trackTitle ?? ""
                            font.pixelSize: Style.px(22)
                            color: Colors.bright
                        }
                        Txt {
                            width: parent.width
                            text: Media.artist
                            color: Colors.accent
                        }
                    }
                    Visualizer {
                        Layout.alignment: Qt.AlignVCenter
                        bars: 6
                        height: 20
                    }
                }

                // ── a notification ──
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    opacity: win.mode === "notify" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.med
                        }
                    }
                    Frame {
                        blob: true
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        color: Colors.accent
                        Icon {
                            anchors.centerIn: parent
                            text: "󰂚"
                            font.pixelSize: 16
                            color: Colors.bg
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Txt {
                            width: parent.width
                            text: (win.note?.appName || "notice").toLowerCase()
                            font.pixelSize: Style.small
                            font.letterSpacing: 1
                            color: Colors.mid
                        }
                        Txt {
                            width: parent.width
                            text: win.note?.summary ?? ""
                            color: Colors.bright
                        }
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: (win.note?.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                            color: Colors.accent
                        }
                    }
                }

                // ── Claude Code: done, or waiting on you ──
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    opacity: win.mode === "claude" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.med
                        }
                    }
                    Frame {
                        blob: true
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        color: win.claudeNeeds ? Colors.bright : Colors.accent
                        Txt {
                            id: claudeMark
                            anchors.centerIn: parent
                            text: "✻"
                            font.pixelSize: Style.px(20)
                            color: Colors.bg
                            // a turn and a little bounce as it arrives
                            function pop() {
                                spin.restart();
                            }
                            ParallelAnimation {
                                id: spin
                                NumberAnimation {
                                    target: claudeMark
                                    property: "rotation"
                                    from: -120
                                    to: 0
                                    duration: 700
                                    easing.type: Easing.OutBack
                                }
                                NumberAnimation {
                                    target: claudeMark
                                    property: "scale"
                                    from: 0.4
                                    to: 1
                                    duration: 700
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.2
                                }
                            }
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Txt {
                            width: parent.width
                            text: "claude" + (win.claudeProject ? "  ·  " + win.claudeProject : "")
                            font.pixelSize: Style.small
                            font.letterSpacing: 1
                            color: Colors.mid
                        }
                        Txt {
                            width: parent.width
                            text: win.claudeText || (win.claudeNeeds ? "needs you" : "done")
                            font.bold: true
                            color: Colors.bright
                        }
                    }
                }

                // a click on a swollen island: the track opens the music panel, a notification the control centre
                MouseArea {
                    anchors.fill: parent
                    visible: win.mode === "track" || win.mode === "notify" || win.mode === "claude"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {                 // (Claude's just goes away)
                        if (win.mode !== "claude")
                            Ui.toggle(win.mode === "track" ? "media" : "control");
                        win.mode = "rest";
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }
        }
    }
}

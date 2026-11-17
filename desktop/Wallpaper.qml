import QtQuick
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import qs.components

// The wallpaper (the theme sets wallpaper_by_shell, so this replaces hyprpaper). A new one wipes up
// from the bottom over the old, behind a thin line in the new accent, the way windows open.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Colors.bg
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "ekitai-wallpaper"

            // `top` shows the wallpaper; for a change, the old one moves to `under`, then the new one
            // loads into `top` and wipes up over it
            property string shown: ""
            readonly property string next: Colors.wallpaper
            property string stage: ""                // "" · "under" (old moving down) · "load" (new loading) · "wipe"
            property real p: 1                       // how much of `top` shows, from the bottom
            property string loading: ""              // the path going into `top`

            onNextChanged: change()
            Component.onCompleted: change()

            function change() {
                if (!next || next === shown || stage)
                    return;
                loading = next;
                if (!shown) {                        // the first one: just show it
                    stage = "load";
                    top.source = "file://" + next;
                    return;
                }
                stage = "under";
                under.source = "file://" + shown;
                underReady();
            }

            function underReady() {
                if (stage !== "under" || under.status !== Image.Ready)
                    return;
                p = 0;
                stage = "load";
                top.source = "file://" + next;
            }

            function topReady() {
                if (stage !== "load" || top.status !== Image.Ready)
                    return;
                if (!shown) {
                    p = 1;
                    showCard();
                    done();
                } else if (album(loading) || album(shown)) {
                    stage = "wipe";                  // only the shell and colours change: nothing to wait for
                    settle.triggered();
                } else {
                    stage = "wipe";
                    settle.restart();
                }
            }

            // the album wallpaper (rice accent --wall), made in $XDG_RUNTIME_DIR/rice-artwall
            function album(path) {
                return path.indexOf("/rice-artwall/") >= 0;
            }

            function showCard() {
                card.art = Colors.art;
                card.title = Media.title;
                card.artist = Media.artist;
                card.album = Media.album;
            }

            function done() {
                shown = loading;
                stage = "";
                change();                            // it changed again meanwhile
            }

            // rice is still reloading hyprland and the terminals when the palette lands; let that pass first
            Timer {
                id: settle
                interval: 150
                onTriggered: {
                    Colors.go();                     // the new colours fade in as it wipes up
                    win.showCard();                  // the album wallpaper's cover and song fade in as it does
                    wipe.restart();
                }
            }

            NumberAnimation {
                id: wipe
                target: win
                property: "p"
                from: 0
                to: 1
                duration: Colors.duration
                easing.type: Easing.InOutCubic
                onFinished: win.done()
            }

            Image {
                id: under
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: win.width
                sourceSize.height: win.height
                asynchronous: true
                onStatusChanged: win.underReady()
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * win.p
                clip: true

                Image {
                    id: top
                    anchors.bottom: parent.bottom
                    width: win.width
                    height: win.height
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: win.width
                    sourceSize.height: win.height
                    asynchronous: true
                    onStatusChanged: win.topReady()
                }
            }

            // the album wallpaper (Settings.artWall): rice makes the backdrop from the cover's colours, and
            // grain, the moving design, the cover and the song go on it here, sharp.
            Item {
                id: card
                property var art: null
                property string title
                property string artist
                property string album
                readonly property int size: Math.round(win.height * 0.36)
                readonly property real r: Look.round ? Math.round(size * 0.06) : 0
                readonly property bool live: Media.title === title

                // the moving design (shaders/artwall.frag), stirred by the music: how loud, from cava's lowest bars
                readonly property var styles: ["waves", "aurora", "drips", "orb"]
                readonly property real hash: {
                    const s = art?.cover ?? "";
                    let h = 7;
                    for (let i = 0; i < s.length; i++)
                        h = (h * 31 + s.charCodeAt(i)) % 1000003;
                    return h / 1000003;
                }
                readonly property int style: Settings.artWallStyle === "shuffle" ? Math.floor(hash * 4) % 4 : Math.max(0, styles.indexOf(Settings.artWallStyle))
                readonly property var cols: art?.colors ?? []
                property real time: 0
                property real energy: 0
                Timer {                              // ~30 frames a second, and none in performance mode
                    running: card.visible && !!card.art && !Perf.low
                    interval: 33
                    repeat: true
                    onTriggered: {
                        card.time += 0.033;
                        const v = Cava.values, n = Math.min(10, v.length);
                        let a = 0;
                        for (let i = 0; i < n; i++)
                            a += v[i];
                        a = n ? Math.min(1, a / n * 1.4) : 0;
                        card.energy += (a - card.energy) * (a > card.energy ? 0.3 : 0.06);
                    }
                }

                ShaderEffect {
                    anchors.fill: parent
                    property size size: Qt.size(width, height)
                    property real time: card.time
                    property real energy: card.energy
                    property real style: card.style
                    property real seed: card.hash * 10
                    property color c0: card.cols[0] ?? Colors.accent
                    property color c1: card.cols[1] ?? Colors.mid
                    property color c2: card.cols[2] ?? card.cols[0] ?? Colors.bright
                    fragmentShader: Qt.resolvedUrl("../shaders/artwall.frag.qsb")
                }

                anchors.fill: parent
                // out while the wallpaper changes, in over the second half of the wipe
                opacity: art && (!win.stage || win.stage === "wipe" && win.p > 0.5) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.slow
                        easing.type: Easing.OutCubic
                    }
                }

                RectangularGlow {
                    x: cover.x
                    y: cover.y + 14
                    width: cover.width
                    height: cover.height
                    glowRadius: 34
                    spread: 0.08
                    cornerRadius: card.r + glowRadius
                    color: Qt.rgba(0, 0, 0, 0.6)
                }

                Item {
                    id: cover
                    x: Math.round(win.width * 0.07)
                    y: Math.round(win.height * 0.42 - height / 2)
                    width: card.size
                    height: card.size
                    layer.enabled: card.r > 0
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: cover.width
                            height: cover.height
                            radius: card.r
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.bg2
                    }
                    Image {
                        anchors.fill: parent
                        source: card.art?.cover ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        sourceSize.width: card.size * 2
                        sourceSize.height: card.size * 2
                    }
                }
                Rectangle {                          // a hairline of light round it
                    anchors.fill: cover
                    radius: card.r
                    color: "transparent"
                    border.width: Style.line
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }

                Column {
                    x: cover.x + cover.width + Math.round(win.width * 0.03)
                    anchors.verticalCenter: cover.verticalCenter
                    width: Math.min(win.width * 0.34, win.width - x - win.width * 0.06)   // clear of the orb
                    spacing: 8

                    Txt {
                        text: Media.playing || !card.live ? "now playing" : "paused"
                        color: Colors.accent
                        opacity: 0.8
                    }
                    Txt {
                        width: parent.width
                        text: card.title
                        color: Colors.bright
                        font.pixelSize: Style.px(44)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                    Txt {
                        width: parent.width
                        text: card.artist
                        visible: !!text
                        font.pixelSize: Style.big
                    }
                    Txt {
                        width: parent.width
                        text: card.album
                        visible: !!text && text !== card.title
                        color: Colors.mid
                    }
                    Item {
                        width: 1
                        height: 10
                    }
                    Row {
                        visible: card.live && Media.length > 0
                        spacing: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(280, card.size)
                            height: 2
                            color: Qt.alpha(Colors.bright, 0.18)

                            Rectangle {
                                width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                                height: parent.height
                                color: Colors.accent
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 1000
                                    }
                                }
                            }
                        }
                        Txt {
                            text: Media.time(Media.position) + " / " + Media.time(Media.length)
                            color: Colors.mid
                        }
                    }
                }
            }

            // the edge of the wipe
            Rectangle {
                visible: wipe.running
                y: parent.height * (1 - win.p) - 1
                width: parent.width
                height: 2
                color: Colors.accent
                opacity: Math.sin(win.p * Math.PI)
            }
        }
    }
}

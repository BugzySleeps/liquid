import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.services
import qs.components

// The equaliser in the music panel: presets along the top, then ten bands (31 Hz … 16 kHz, ±12 dB).
// Drag a knob (or scroll on its column) to change a band, double-click to flatten it. The knobs are
// joined by a smooth curve; everything takes the current shape (square, round or squiggle).
Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── presets + on/off ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: Eq.presets
                    Chip {
                        required property string modelData
                        text: modelData
                        on: Eq.preset === modelData
                        onClicked: Eq.usePreset(modelData)
                    }
                }
            }
            Chip {
                text: Eq.on ? "󰺢 on" : "off"
                on: Eq.on
                onClicked: Eq.toggle()
            }
        }

        // ── the bands ──
        Item {
            id: bands
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: Eq.on ? 1 : 0.45
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.med
                }
            }

            readonly property real labelH: 14
            readonly property real trackTop: 6
            readonly property real trackBottom: height - labelH - 4
            readonly property real colW: width / 10
            function yOf(db) {
                return trackTop + (12 - db) / 24 * (trackBottom - trackTop);
            }
            function xOf(i) {
                return colW * i + colW / 2;
            }

            // the 0 dB line
            Rectangle {
                y: bands.yOf(0)
                width: parent.width
                height: 1
                color: Colors.faint
            }

            // the curve through the knobs (Catmull-Rom, sampled)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Colors.accent, 0.8)
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline {
                        path: {
                            const g = Eq.gains, pts = [];
                            const P = i => Qt.point(bands.xOf(i), bands.yOf(g[Math.max(0, Math.min(9, i))]));
                            for (let i = 0; i < 9; i++) {
                                const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
                                for (let s = 0; s < 1; s += 0.1) {
                                    const s2 = s * s, s3 = s2 * s;
                                    pts.push(Qt.point(
                                        0.5 * (2 * p1.x + (-p0.x + p2.x) * s + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * s2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * s3),
                                        0.5 * (2 * p1.y + (-p0.y + p2.y) * s + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * s2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * s3)));
                                }
                            }
                            pts.push(P(9));
                            return pts;
                        }
                    }
                }
            }

            Repeater {
                model: 10
                Item {
                    id: band
                    required property int index
                    readonly property real db: Eq.gains[index]
                    x: bands.colW * index
                    width: bands.colW
                    height: bands.height

                    // the track: a column of segments (dots when round)
                    Column {
                        x: (parent.width - width) / 2
                        y: bands.trackTop
                        spacing: 3
                        Repeater {
                            model: Math.max(1, Math.floor((bands.trackBottom - bands.trackTop) / 7))
                            Rectangle {
                                width: Look.round ? 4 : 6
                                height: 4
                                radius: Look.round ? 2 : 0
                                color: Colors.faint
                            }
                        }
                    }

                    // the knob
                    Frame {
                        id: knob
                        blob: true
                        width: drag.pressed || drag.containsMouse ? 16 : 13
                        height: width
                        x: (parent.width - width) / 2
                        y: bands.yOf(band.db) - height / 2
                        color: drag.pressed ? Colors.bright : Colors.accent
                        Behavior on width {
                            NumberAnimation {
                                duration: Style.fast
                            }
                        }
                    }

                    // its value, while it's being touched
                    Txt {
                        visible: drag.pressed || drag.containsMouse
                        anchors.horizontalCenter: knob.horizontalCenter
                        y: knob.y - 16
                        text: (band.db > 0 ? "+" : "") + band.db.toFixed(1)
                        font.pixelSize: Style.small
                        color: Colors.bright
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: bands.height - bands.labelH
                        text: Eq.label(Eq.freqs[band.index])
                        font.pixelSize: Style.small
                        color: Colors.mid
                    }

                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        function dbAt(y) {
                            return 12 - (y - bands.trackTop) / (bands.trackBottom - bands.trackTop) * 24;
                        }
                        onPressed: e => Eq.setBand(band.index, dbAt(e.y))
                        onPositionChanged: e => {
                            if (pressed)
                                Eq.setBand(band.index, dbAt(e.y));
                        }
                        onDoubleClicked: Eq.setBand(band.index, 0)
                        onWheel: e => Eq.setBand(band.index, band.db + (e.angleDelta.y > 0 ? 0.5 : -0.5))
                    }
                }
            }
        }
    }
}

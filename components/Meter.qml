import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// A level meter. The fill eases between values.
//   square: segments ▰▰▰▰▱▱▱ · round: pill segments · squiggle: a wavy line that fills up
Item {
    id: root

    property real value: 0
    property int segments: 10
    property int segWidth: 6
    property int segHeight: 10
    property int spacing: 2
    property color on: Colors.accent
    property color off: Colors.faint

    property real shown: value
    Behavior on shown {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }

    implicitWidth: segments * segWidth + (segments - 1) * spacing
    implicitHeight: segHeight

    Row {
        visible: !Look.wavy
        spacing: root.spacing
        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                width: root.segWidth
                height: root.segHeight
                // the segment the level ends in fills partly, so small changes still show
                readonly property real fill: Math.max(0, Math.min(1, root.shown * root.segments - index))
                color: root.off
                radius: Look.round ? Math.min(width, height) / 2 : 0
                clip: Look.round
                Rectangle {
                    width: parent.width
                    height: parent.height * parent.fill
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.on
                }
            }
        }
    }

    // ── squiggle: the filled part is a wave, the rest a flat line ──
    Item {
        id: wv
        anchors.fill: parent
        visible: Look.wavy
        readonly property real th: Math.max(2, Math.min(3, root.height / 4))
        readonly property real amp: Math.max(1, Math.min(2.5, root.height / 2 - th))
        readonly property real split: Math.max(th, root.width * root.shown)
        property real phase: 0
        NumberAnimation on phase {
            running: Look.wavy && root.visible && !Perf.low
            from: 0
            to: 2 * Math.PI
            duration: 1600
            loops: Animation.Infinite
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.off
                strokeWidth: wv.th
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: Math.min(root.width - 1, wv.split + 5)
                startY: root.height / 2
                PathLine {
                    x: root.width - wv.th / 2
                    y: root.height / 2
                }
            }
            ShapePath {
                strokeColor: root.on
                strokeWidth: wv.th
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathPolyline {
                    path: {
                        const w = wv, pts = [];
                        for (let x = w.th / 2; x <= w.split; x += 1.5)
                            pts.push(Qt.point(x, root.height / 2 + w.amp * Math.sin(x / 9 * 2 * Math.PI - w.phase)));
                        return pts;
                    }
                }
            }
        }
    }
}

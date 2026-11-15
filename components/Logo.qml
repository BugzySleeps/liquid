import QtQuick
import QtQuick.Shapes

// The ekitai logo: a drop falling into rings of ripples (assets/logo/make.py draws the same one as files).
// It's drawn, not an image, so it takes any colour. `small` (on by itself under 64 px) is the plainer
// version for icons: two solid rings, a bigger drop, no trail. drip() plays it once: the drop falls in, the rings spread
// out from where it hit, a new drop forms. `live` drips every `every` ms.
Item {
    id: logo

    property color color: "white"
    property bool small: Math.min(width, height) < 64
    property bool live: false
    property int every: 4200

    implicitWidth: 256
    implicitHeight: 256

    property real fall: 0                        // the drop: 0 hanging … 1 in the water
    property real form: 1                        // the next drop forming: 0 … 1
    property real wave: 1                        // the rings: 0 just hit … 1 at rest

    function drip() {
        if (!anim.running)
            anim.restart();
    }

    SequentialAnimation {
        id: anim
        NumberAnimation {
            target: logo
            property: "fall"
            to: 1
            duration: 420
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                logo.wave = 0;
                logo.form = 0;
                logo.fall = 0;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: logo
                property: "wave"
                to: 1
                duration: 1300
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 500
                }
                NumberAnimation {
                    target: logo
                    property: "form"
                    to: 1
                    duration: 650
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Timer {
        running: logo.live && logo.visible
        interval: logo.every
        repeat: true
        triggeredOnStart: true
        onTriggered: logo.drip()
    }

    // [rx, ry, width, dash %, gap %, opacity]: squashed ellipses, lying on the water
    readonly property var rings: small ? [[52, 16, 13, 0, 0, 1], [108, 34, 11, 0, 0, 0.7]] : [[28, 9.5, 7, 0, 0, 1], [60, 20, 6, 15, 2, 0.85], [92, 31, 5, 5, 2.2, 0.6], [120, 40.5, 4, 1.4, 2, 0.4]]
    readonly property real cy: small ? 196 : 190

    // drawn in a 256 × 256 space, scaled to fit (rendered in a layer at full size, so small ones stay smooth)
    Item {
        id: art
        width: 256
        height: 256
        x: (logo.width - 256 * scale) / 2
        y: (logo.height - 256 * scale) / 2
        scale: Math.min(logo.width, logo.height) / 256
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        Item {
            anchors.fill: parent

            Repeater {
                model: logo.rings
                Shape {
                    id: ring
                    required property var modelData
                    required property int index
                    readonly property real a: modelData[0]
                    readonly property real b: modelData[1]
                    readonly property real w: modelData[2]
                    readonly property real around: Math.PI * (3 * (a + b) - Math.sqrt((3 * a + b) * (a + 3 * b)))
                    // spreading after a drop: each ring a little after the one inside it
                    readonly property real t: Math.max(0, Math.min(1, (logo.wave * 1.3 - index * 0.13) / 0.8))
                    readonly property real eased: 1 - Math.pow(1 - t, 3)
                    anchors.fill: parent
                    opacity: modelData[5] * Math.min(1, t * 3)
                    transform: Scale {
                        origin.x: 128
                        origin.y: logo.cy
                        xScale: 0.25 + 0.75 * ring.eased
                        yScale: xScale
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: logo.color
                        strokeWidth: ring.w
                        strokeStyle: ring.modelData[3] ? ShapePath.DashLine : ShapePath.SolidLine
                        // the pattern counts in stroke widths; the files' in percent of the ring
                        dashPattern: ring.modelData[3] ? [ring.modelData[3] / 100 * ring.around / ring.w, ring.modelData[4] / 100 * ring.around / ring.w] : [1, 0]
                        capStyle: ShapePath.FlatCap
                        PathAngleArc {
                            centerX: 128
                            centerY: logo.cy
                            radiusX: ring.a
                            radiusY: ring.b
                            startAngle: 0
                            sweepAngle: 360
                            moveToStart: true
                        }
                    }
                }
            }

            // the fall: two dots between the drop and the water
            Repeater {
                model: logo.small ? [] : [[124, 4, 0.7], [142, 3, 0.45]]
                Rectangle {
                    required property var modelData
                    x: 128 - modelData[1]
                    y: modelData[0] - modelData[1]
                    width: modelData[1] * 2
                    height: width
                    radius: width / 2
                    color: logo.color
                    opacity: modelData[2] * logo.form * (1 - logo.fall)
                }
            }

            Shape {
                id: drop
                anchors.fill: parent
                opacity: logo.form * (1 - Math.pow(logo.fall, 3))
                transform: [
                    Scale {                      // forming: grows from its tip; falling: stretches a little
                        origin.x: 128
                        origin.y: 22
                        xScale: 0.3 + 0.7 * logo.form
                        yScale: (0.3 + 0.7 * logo.form) * (1 + 0.18 * logo.fall)
                    },
                    Scale {                      // small: a bigger drop, a little higher
                        origin.x: 128
                        origin.y: 22
                        xScale: logo.small ? 1.35 : 1
                        yScale: xScale
                    },
                    Translate {
                        y: logo.fall * (logo.small ? 64 : 98) - (logo.small ? 4 : 0)
                    }
                ]
                ShapePath {
                    fillColor: logo.color
                    strokeColor: "transparent"
                    PathSvg {
                        path: "M128 22 C128 22 103 60 103 80 A25 25 0 0 0 153 80 C153 60 128 22 128 22 Z"
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Shapes
import qs.config

// Glowing liquid filling this item from the bottom to `level` (0–1). The level springs to a new value
// (overshooting a little), the surface sloshes when it moves and settles down, and `bubbles` sends a few
// rising. It only animates while something is moving (or `alive`), so a still gauge costs nothing.
// Cut it to a shape with a mask on its parent (see Vial.qml).
Item {
    id: root

    property real level: 0
    property bool bubbles: false
    property bool alive: false                   // keep the surface rolling gently even when still
    property color color: Colors.accent
    property color glow: Colors.bright
    property real ripple: 1.2                    // the surface's resting wave, in pixels
    property real sloshScale: 1                  // how hard it sloshes (lower for a long, thin container)

    property real shown: level
    Behavior on shown {
        SpringAnimation {
            spring: 3.2
            damping: 0.22
            epsilon: 0.002
        }
    }
    onLevelChanged: slosh = Math.min(height * 0.12, slosh + Math.abs(level - shown) * height * 0.5 + 1.5) * sloshScale

    property real slosh: 0                       // extra wave height, decaying
    property real time: 0
    readonly property bool moving: slosh > 0.05 || Math.abs(shown - level) > 0.002
    FrameAnimation {
        running: root.visible && (root.moving || root.bubbles || root.alive)
        onTriggered: {
            root.time += frameTime;
            root.slosh *= Math.pow(0.12, frameTime);
        }
    }

    function surfaceAt(x) {
        const k = 2 * Math.PI / Math.max(24, width * 1.1);
        const a = (alive || bubbles || moving ? ripple : 0) + slosh;
        return height * (1 - shown) + Math.sin(x * k + time * 3.1) * a + Math.sin(x * k * 2.3 - time * 4.7) * a * 0.35;
    }
    readonly property var surface: {
        time;
        shown;
        slosh;
        const pts = [];
        const step = Math.max(1, width / 40);
        for (let x = 0; x <= width + 0.01; x += step)
            pts.push(Qt.point(x, surfaceAt(x)));
        return pts;
    }

    Shape {
        anchors.fill: parent
        visible: root.shown > 0.003
        preferredRendererType: Shape.CurveRenderer

        ShapePath {                              // the body
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: root.height * (1 - root.shown)
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.alpha(root.color, 0.95)
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(root.color, 2.2)
                }
            }
            PathPolyline {
                path: [...root.surface, Qt.point(root.width, root.height + 1), Qt.point(0, root.height + 1)]
            }
        }
        ShapePath {                              // the bright surface line
            strokeColor: root.glow
            strokeWidth: Math.max(1, Math.min(2, root.width / 20))
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: root.surface
            }
        }
    }

    // bubbles: a few, each rising at its own pace and wobbling
    Repeater {
        model: root.bubbles ? 5 : 0
        Rectangle {
            required property int index
            readonly property real speed: 0.35 + (index * 0.37) % 0.5
            readonly property real r: Math.max(1.5, root.width * (0.06 + (index % 3) * 0.025))
            readonly property real p: (root.time * speed + index * 0.29) % 1
            readonly property real ceil: root.height * (1 - root.shown) + 3
            width: r * 2
            height: r * 2
            radius: r
            x: root.width * ((index * 0.23 + 0.12) % 0.8 + 0.06) + Math.sin(root.time * 3 + index) * root.width * 0.04
            y: root.height - p * (root.height - ceil) - r
            visible: y > ceil
            color: Qt.alpha(root.glow, 0.55 * (1 - p))
        }
    }
}

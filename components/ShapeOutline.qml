import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import "Shapes.js" as Shapes

// A widget's shape (components/Shapes.js), filled and outlined, morphing into a new one when `shape` changes
// (a little springy). `angle` sets it at a tilt and `turn` spins it on top of that (both 0–1 of a turn). `inner` is the box its content gets ([width, height], 0–1
// of its own): the biggest that fits with room for `need` ([w, h] px inside `pad`), or else for `least`
// (Shapes.place).
Item {
    id: root

    property string shape: "box"
    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real turn: 0
    property real angle: 0                       // a tilt the content keeps clear of (the spin isn't)
    property real angleShown: angle              // where the outline's drawn (can lag behind, easing to `angle`)
    property var need: [0, 0]
    property var least: need
    property real pad: 0
    property Item fillItem: null                 // fill it with this (a picture) instead of `color`
    property bool curve: true                    // false for masks: the curve renderer doesn't draw into a hidden layer
    readonly property bool sheen: Look.glass && color.a > 0.05 && color.a < 0.99
    // Colors.glass: filled with the shell's liquid glass (GlassFill), which needs to know where it is on screen
    property var screenAt: null
    readonly property bool glassy: Look.glass && !fillItem && Qt.colorEqual(color, Colors.glass)

    // the rays: what it's morphing from, to, and how far along
    property var from: []
    property var to: []
    property real t: 1
    readonly property var now: from.length && t < 1 ? Shapes.mix(from, to, t) : to
    readonly property var tilted: Shapes.turned(to, angle)
    readonly property var inner: to.length ? Shapes.place(tilted, width, height, need, least, pad) : [1, 1, true]
    // the radius of the biggest circle that fits (round content fills that instead of `inner`'s box)
    readonly property real reach: to.length ? Shapes.reach(tilted, width, height) : Math.min(width, height) / 2

    function target() {
        return Shapes.rays(shape, width, height, Look.r(width, height));
    }
    onShapeChanged: {
        if (!to.length || width <= 0)
            return;
        from = now;
        to = target();
        morph.restart();
    }
    // a box or a pill depends on the size: follow it straight away (resizing shouldn't wobble)
    onWidthChanged: refit()
    onHeightChanged: refit()
    function refit() {
        if (width <= 0 || height <= 0)
            return;
        if (!to.length || Shapes.free(shape)) {
            to = target();
            if (!morph.running)
                from = [];
        }
    }
    Connections {
        target: Look
        function onShapeChanged() {
            root.refit();
        }
    }

    NumberAnimation {
        id: morph
        target: root
        property: "t"
        from: 0
        to: 1
        duration: 650
        easing.type: Easing.OutBack
        easing.overshoot: 1.4
    }

    Loader {
        id: glassLoader
        anchors.fill: parent
        active: root.glassy
        sourceComponent: GlassFill {
            masked: false
            screenAt: root.screenAt
        }
    }
    ShaderEffectSource {
        id: glassTex
        anchors.fill: parent
        sourceItem: glassLoader.item
        hideSource: true
        visible: false
    }

    Shape {
        anchors.fill: parent
        visible: root.now.length > 0
        preferredRendererType: root.curve ? Shape.CurveRenderer : Shape.GeometryRenderer

        ShapePath {
            fillColor: root.color
            fillItem: root.glassy ? glassTex : root.fillItem
            strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                id: outline
                path: root.now.length ? Shapes.points(root.now, root.width, root.height, root.turn + root.angleShown, root.borderWidth / 2) : []
            }
        }
        ShapePath {                              // liquid glass: light on the rim
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 1, 1, 0.45 * Look.tune.shine)
            strokeWidth: 1.2
            PathPolyline {
                path: root.glassy ? Shapes.points(root.now, root.width, root.height, root.turn + root.angleShown, root.borderWidth + 1) : []
            }
        }
        ShapePath {                              // the glass sheen
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.13)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
            PathPolyline {
                path: root.sheen ? outline.path : []
            }
        }
    }
}

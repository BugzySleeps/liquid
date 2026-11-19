import QtQuick
import Quickshell
import qs.config
import qs.services

// The glass look's fill (shaders/glass.frag): the blurred wallpaper behind it, bent at the rim, tinted, with
// light on the edge. Frame and ShapeOutline put it under themselves. `screenAt`: where it is on screen, for
// when it's drawn off screen (a widget's shape) and can't tell by itself; `masked: false` when something
// else cuts the outline.
ShaderEffect {
    id: root

    property real radius: 0
    property real inset: 0
    property bool circle: false
    property vector4d wave: Qt.vector4d(0, 0, 0, 0)    // squiggle's outline (glass.frag)
    property bool masked: true
    property var screenAt: null
    // the tint: the theme's dark with a touch of its colour, or a neutral smoke; how much, from Look.tune
    readonly property color hue: Look.tune.hue === "neutral" ? Qt.rgba(0.05, 0.055, 0.07, 1) : Qt.tint(Colors.bg, Qt.alpha(Colors.accent, 0.07))
    property color tintColor: Qt.alpha(hue, 0.05 + 0.8 * Look.tune.tint)

    readonly property var origin: Glass.origin(QsWindow.window)
    readonly property bool seen: Glass.backdrop !== "" && (origin !== null || screenAt !== null)

    Image {
        id: pic
        source: Glass.backdrop
        asynchronous: true
        visible: false
        smooth: true
    }
    readonly property var source: pic

    readonly property vector4d win: Qt.vector4d(origin?.x ?? 0, origin?.y ?? 0, QsWindow.window?.width ?? 1, QsWindow.window?.height ?? 1)
    readonly property vector4d at: Qt.vector4d(screenAt?.x ?? 0, screenAt?.y ?? 0, screenAt ? 1 : 0, 0)
    readonly property size size: Qt.size(width, height)
    readonly property size screen: Qt.size(Glass.screen?.width ?? 1600, Glass.screen?.height ?? 900)
    readonly property color tint: tintColor
    readonly property color light: Colors.bright
    readonly property real round: circle ? 1 : 0
    readonly property real back: seen && pic.status === Image.Ready ? 1 : 0
    readonly property real edge: masked ? 1 : 0
    readonly property vector4d turn: Qt.vector4d(Glass.shift, Glass.sat, 0, 0)
    readonly property vector4d tune: Qt.vector4d(Look.tune.bend, Look.tune.shine, 1.15 + 0.35 * Look.tune.bend, 0)

    vertexShader: Qt.resolvedUrl("../shaders/glass.vert.qsb")
    fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb") + "?2"   // versioned: see Wallpaper.qml's livewall
}

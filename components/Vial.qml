import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services

// Liquid in a container: a capsule in round / squiggle, square-cornered in square. The container is a
// faint glass shape with a hairline edge; the liquid is cut to its inside.
Item {
    id: root

    property alias level: liquid.level
    property alias bubbles: liquid.bubbles
    property alias alive: liquid.alive
    property alias color: liquid.color
    property alias sloshScale: liquid.sloshScale
    property real inset: 2
    readonly property real radius: Look.round ? Math.min(width, height) / 2 : 1

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colors.bg2, 0.8)
        border.width: Style.line
        border.color: Colors.faint
    }

    Item {
        id: inside
        anchors.fill: parent
        anchors.margins: root.inset
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: mask
        }
        Liquid {
            id: liquid
            anchors.fill: parent
        }
    }
    Rectangle {
        id: mask
        anchors.fill: inside
        visible: false
        layer.enabled: true
        radius: Math.max(0, root.radius - root.inset)
    }

    // a highlight down one side, like light on glass
    Rectangle {
        x: root.width * 0.18
        y: root.radius * 0.6
        width: Math.max(1, root.width * 0.08)
        height: root.height - root.radius * 1.2
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.08)
    }
}

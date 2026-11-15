import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services

// Cover art, recoloured into the theme's accent and cut to the current Look: a square, a rounded
// square, or (squiggle) a scalloped cookie that slowly turns while music plays. A music glyph when there's none.
Item {
    id: root

    property url source
    property int sourceSize: 256
    property color borderColor: Colors.dim
    property bool turning: false
    readonly property bool cookie: Look.wavy

    property real spin: 0
    NumberAnimation on spin {
        running: root.cookie && root.turning && root.visible
        from: root.spin
        to: root.spin + 360
        duration: 24000
        loops: Animation.Infinite
    }

    Frame {
        anchors.fill: parent
        blob: root.cookie
        spin: root.spin
        color: Colors.bg1
        border.width: Style.line
        border.color: root.borderColor
    }

    Item {
        id: cut
        anchors.fill: parent
        anchors.margins: root.cookie ? 2 : 1
        layer.enabled: Look.round
        layer.effect: OpacityMask {
            maskSource: mask
        }

        Image {
            id: art
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.sourceSize
            sourceSize.height: root.sourceSize
            layer.enabled: true
            layer.effect: Colorize {
                hue: Colors.accent.hslHue
                saturation: 0.7
                lightness: -0.1
            }
        }
    }

    // the mask is rebuilt whenever the shape changes: a shape that starts hidden in a mask layer never draws
    Loader {
        id: mask
        anchors.fill: cut
        visible: false
        layer.enabled: true
        layer.samples: 4
        sourceComponent: root.cookie ? cookieMask : roundMask
    }
    Component {
        id: cookieMask
        Frame {
            blob: true
            curve: false
            spin: root.spin
            color: "white"
        }
    }
    Component {
        id: roundMask
        Rectangle {
            radius: Look.r(width, height) - 1
            color: "white"
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "󰝚"
        font.pixelSize: parent.width * 0.35
        color: Colors.dim
    }
}

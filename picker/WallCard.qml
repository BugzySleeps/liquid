import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config
import qs.components
import qs.services

// One wallpaper in the picker: just the picture, slanted like a card in a fan, outlined in its own
// accent when it's the one selected. (Its name and colours show once, under the carousel.)
Item {
    id: card

    required property var wall
    property int number: 1
    property bool selected: false
    property bool near: true
    readonly property alias shot: shot
    signal picked

    readonly property color accent: wall.colors?.accent ?? Colors.accent
    readonly property real slant: 0.2             // the lean, as a fraction of the height

    height: Math.round(width * 10 / 16)

    // lean the card: the top shifts right, the bottom left, around its middle
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, -card.slant, 0, card.slant * card.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    Item {
        id: shot
        anchors.fill: parent
        layer.enabled: Look.round
        layer.effect: OpacityMask {
            maskSource: shotMask
        }

        Rectangle {
            id: shotMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            radius: Look.radius
        }
        Rectangle {
            anchors.fill: parent
            color: card.wall.colors?.bg1 ?? Colors.bg1
        }
        Image {
            anchors.fill: parent
            source: card.near && card.wall.path ? "file://" + card.wall.path : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 960
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.med
                }
            }
        }
        // the ones not selected sit back a little
        Rectangle {
            anchors.fill: parent
            color: Colors.bg
            opacity: card.selected ? 0 : 0.35
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.med
                }
            }
        }
    }

    // the outline, in the wallpaper's own accent
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Look.round ? Look.radius + 3 : 0
        color: "transparent"
        border.width: 2
        border.color: card.accent
        opacity: card.selected ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.med
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.picked()
    }
}

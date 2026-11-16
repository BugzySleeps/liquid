import QtQuick
import qs.config

// A square toggle: icon, label and a small status line. Solid green when on. With `more`, a chevron on its
// right opens its details (expand()); `expanded` turns it.
Frame {
    id: root

    property string icon: ""
    property string label: ""
    property string status: ""
    property bool on: false
    property bool more: false
    property bool expanded: false
    signal clicked
    signal expand

    implicitHeight: 54
    color: on ? Colors.accent : area.containsMouse ? Colors.bg3 : Colors.bg2

    Behavior on color {
        ColorAnimation {
            duration: Style.fast
        }
    }

    Icon {
        id: glyph
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.pixelSize: 18
        color: root.on ? Colors.bg : Colors.accent
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: 10
        anchors.right: root.more ? chevron.left : parent.right
        anchors.rightMargin: root.more ? 2 : 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Txt {
            width: parent.width
            text: root.label
            font.bold: true
            color: root.on ? Colors.bg : Colors.accent
        }
        Txt {
            width: parent.width
            text: root.status
            font.pixelSize: Style.small
            color: root.on ? Colors.bg2 : Colors.mid
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Item {
        id: chevron
        visible: root.more
        anchors.right: parent.right
        width: 28
        height: parent.height
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.line
            height: parent.height - 18
            color: root.on ? Colors.bg2 : Colors.faint
        }
        Icon {
            anchors.centerIn: parent
            text: "󰅂"
            font.pixelSize: 13
            rotation: root.expanded ? 90 : 0
            color: moreArea.containsMouse ? (root.on ? Colors.bg2 : Colors.bright) : root.on ? Colors.bg : Colors.accent
            Behavior on rotation {
                NumberAnimation {
                    duration: Style.fast
                }
            }
        }
        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expand()
        }
    }
}

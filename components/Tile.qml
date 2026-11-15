import QtQuick
import qs.config

// A square toggle: icon, label and a small status line. Solid green when on.
Frame {
    id: root

    property string icon: ""
    property string label: ""
    property string status: ""
    property bool on: false
    signal clicked

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
        anchors.right: parent.right
        anchors.rightMargin: 8
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
}

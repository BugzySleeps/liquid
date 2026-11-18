import QtQuick
import qs.config

// A small on/off choice: filled green when on.
Frame {
    id: root
    pill: true

    property string text: ""
    property bool on: false
    property int minWidth: 26
    property string family: ""                   // a font of its own (the font picker writes each in itself)
    signal clicked

    implicitWidth: Math.max(minWidth, label.implicitWidth + 14)
    implicitHeight: 22
    color: on ? Colors.accent : area.containsMouse ? Colors.bg3 : Colors.bg2

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Style.small
        font.family: root.family || Style.font
        font.bold: root.on
        color: root.on ? Colors.bg : Colors.accent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

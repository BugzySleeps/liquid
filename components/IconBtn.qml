import QtQuick
import qs.config

// An icon button (square, a circle, or a scalloped cookie: see Look) with a hairline border. Hover inverts it; `armed` keeps it inverted.
Frame {
    id: root
    blob: true

    property string icon: ""
    property string tip: ""
    property bool armed: false
    property int size: 32
    property int iconSize: 15
    signal clicked

    readonly property bool lit: armed || area.containsMouse

    implicitWidth: size
    implicitHeight: size
    color: lit ? Colors.accent : Colors.bg2

    Behavior on color {
        ColorAnimation {
            duration: Style.fast
        }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: root.iconSize
        color: root.lit ? Colors.bg : Colors.accent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

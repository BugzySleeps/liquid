import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// One item in a bar island. Hover lifts it a shade and underlines it in green, and slides out its `hint`
// (the detail an icon stands for: the wifi name, the volume) so the bar can stay icons.
Rectangle {
    id: root

    property int pad: 10
    property bool interactive: true
    property string hint: ""
    readonly property real hintW: hint && area.containsMouse ? hintText.implicitWidth + 6 : 0
    default property alias content: row.data
    signal clicked(var mouse)
    signal scrolled(int dir)

    implicitWidth: row.implicitWidth + hintShown + pad * 2
    property real hintShown: hintW
    Behavior on hintShown {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }
    implicitHeight: Style.barHeight - 2
    // round looks: the hover is a pill too, so it fits the island's rounded ends (it was a box poking out)
    radius: Look.round ? height / 2 : 0
    color: interactive && area.containsMouse ? Colors.bg2 : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.fast
        }
    }

    // a RowLayout centres icons and text vertically, whatever their heights
    RowLayout {
        id: row
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
    Item {
        x: row.x + row.implicitWidth
        width: root.hintShown
        height: parent.height
        clip: true
        Txt {
            id: hintText
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            color: Colors.bright
            opacity: root.hintW > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.fast
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !Look.round                     // round looks: the pill highlight is enough
        height: 2
        width: root.interactive && area.containsMouse ? parent.width : 0
        color: Colors.accent
        Behavior on width {
            NumberAnimation {
                duration: Style.med
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor   // (a disabled one still sets it)
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}

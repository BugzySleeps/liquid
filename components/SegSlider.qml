import QtQuick
import qs.config

// A Meter you can click, drag or scroll. Emits moved(value) with 0..1.
Item {
    id: root

    property real value: 0
    property int segments: 20
    signal moved(real v)

    implicitWidth: meter.implicitWidth
    implicitHeight: 14

    Meter {
        id: meter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        segments: root.segments
        segWidth: Math.max(3, Math.floor((root.width - (root.segments - 1) * 2) / root.segments))
        segHeight: area.containsMouse ? 12 : 10
        value: root.value
        on: area.containsMouse ? Colors.bright : Colors.accent
        Behavior on segHeight {
            NumberAnimation {
                duration: Style.fast
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x) {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: e => root.moved(at(e.x))
        onPositionChanged: e => {
            if (pressed)
                root.moved(at(e.x));
        }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}

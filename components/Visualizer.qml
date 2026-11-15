import QtQuick
import qs.config
import qs.services

// cava bars growing up from the bottom. `bars` picks evenly from Cava's 30.
Item {
    id: root

    property int bars: 10
    property int barWidth: 2
    property int spacing: 2
    property color color: Colors.accent

    implicitWidth: bars * barWidth + (bars - 1) * spacing
    implicitHeight: 14

    Row {
        anchors.bottom: parent.bottom
        spacing: root.spacing
        Repeater {
            model: root.bars
            Rectangle {
                required property int index
                readonly property real v: Cava.values.length ? Cava.values[Math.floor(index * Cava.values.length / root.bars)] : 0
                anchors.bottom: parent.bottom
                width: root.barWidth
                height: Math.max(Look.round ? width : 1, v * root.height)
                visible: v > 0.02                // silence: no flat stubs
                radius: Look.round ? width / 2 : 0
                color: root.color
                Behavior on height {
                    NumberAnimation {
                        duration: 60
                    }
                }
            }
        }
    }
}

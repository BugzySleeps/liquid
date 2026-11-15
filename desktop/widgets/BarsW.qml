import QtQuick
import qs.config
import qs.services
import qs.components

// cava, big. A flat dim line while nothing plays.
Item {
    id: root
    property var wd

    readonly property int count: Math.max(8, Math.min(Cava.bars, Math.floor(width / 10)))

    Visualizer {
        anchors.fill: parent
        bars: root.count
        spacing: 3
        barWidth: Math.max(2, Math.floor((root.width - (root.count - 1) * 3) / root.count))
    }

    Rectangle {
        visible: !Media.playing
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Colors.dim
    }
    Txt {
        visible: !Media.playing
        anchors.centerIn: parent
        text: "silence"
        color: Colors.dim
        font.letterSpacing: 4
    }
}

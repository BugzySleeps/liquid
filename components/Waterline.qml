import QtQuick
import qs.config
import qs.services

// cava as a waterline: bars rise from a line across the middle, and their reflections hang under it,
// fainter and rippling, as if the music were standing in the liquid.
Item {
    id: root

    property int bars: 16
    property real gap: 3
    property color color: Colors.accent

    implicitWidth: 120
    implicitHeight: 140

    readonly property real line: height * 0.58             // the waterline, a little below the middle
    readonly property real barW: Math.max(2, (width - (bars - 1) * gap) / bars)
    property real phase: 0
    NumberAnimation on phase {
        running: root.visible && Media.playing && !Perf.low
        from: 0
        to: 2 * Math.PI
        duration: 1800
        loops: Animation.Infinite
    }

    Repeater {
        model: root.bars
        Item {
            id: bar
            required property int index
            readonly property real v: Cava.values.length ? Cava.values[Math.floor(index * Cava.values.length / root.bars)] : 0
            property real shown: v
            Behavior on shown {
                NumberAnimation {
                    duration: 70
                }
            }
            x: index * (root.barW + root.gap)
            width: root.barW
            height: root.height

            // above the line
            Rectangle {
                visible: bar.shown > 0.02        // silence: nothing, not a dashed line
                width: parent.width
                height: Math.max(2, bar.shown * root.line * 0.95)
                y: root.line - height
                radius: Look.round ? width / 2 : 0
                color: root.color
            }
            // the reflection: shorter, fainter, rippling sideways
            Rectangle {
                visible: bar.shown > 0.02
                width: parent.width
                height: Math.max(1, bar.shown * (root.height - root.line) * 0.8)
                y: root.line + 2
                x: Math.sin(root.phase + bar.index * 0.7) * 1.5
                radius: Look.round ? width / 2 : 0
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.color, 0.45)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.color, 0)
                    }
                }
            }
        }
    }

    // the line itself (only while something plays)
    Rectangle {
        visible: Media.playing
        y: root.line
        width: parent.width
        height: 1
        color: Qt.alpha(root.color, 0.5)
    }
}

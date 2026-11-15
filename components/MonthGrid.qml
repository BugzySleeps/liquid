import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// A Monday-first month with ‹ › paging and today filled in. Used by the calendar panel and widget.
Column {
    id: root

    property int offset: 0          // months from now
    property int cellHeight: 24
    property bool paging: true

    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + offset, 1)

    spacing: 6

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    RowLayout {
        width: parent.width
        IconBtn {
            visible: root.paging
            icon: "󰅁"
            size: 22
            iconSize: 12
            onClicked: root.offset--
        }
        Txt {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy").toLowerCase()
            font.bold: true
        }
        IconBtn {
            visible: root.paging
            icon: "󰅂"
            size: 22
            iconSize: 12
            onClicked: root.offset++
        }
    }

    Grid {
        id: grid
        width: parent.width
        columns: 7
        readonly property real cell: width / 7

        Repeater {
            model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
            Txt {
                required property string modelData
                width: grid.cell
                height: 18
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }

        Repeater {
            model: 42
            Frame {
                required property int index
                blob: true
                readonly property int lead: (root.shown.getDay() + 6) % 7
                readonly property date day: new Date(root.shown.getFullYear(), root.shown.getMonth(), index - lead + 1)
                readonly property bool inMonth: day.getMonth() === root.shown.getMonth()
                readonly property bool today: day.toDateString() === clock.date.toDateString()
                width: grid.cell
                height: root.cellHeight
                color: today ? Colors.accent : "transparent"
                border.width: dayArea.containsMouse && !today ? Style.line : 0
                border.color: Colors.accent
                Txt {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    color: parent.today ? Colors.bg : parent.inMonth ? Colors.accent : Colors.dim
                    font.bold: parent.today
                }
                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}

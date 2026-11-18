import QtQuick
import Quickshell
import qs.config
import qs.components

// Today as a card (the weekday, the date big, the month); click it and the widget swells into the whole month
// (WidgetFrame.opened): the card's date drops away and the days pop in one after another. The × (or the month's
// name) folds it back, and the card pops back up.
Item {
    id: root
    property var wd
    property bool open: false
    signal toggle

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── the day card ──
    Column {
        id: card
        anchors.centerIn: parent
        width: parent.width
        spacing: 0
        opacity: root.open ? 0 : 1
        // opening: it sinks back and fades; closing: it springs back up, a little past full size
        scale: root.open ? 0.6 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 160 : 380
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 200 : 520
                easing.type: root.open ? Easing.InCubic : Easing.OutBack
                easing.overshoot: 2.4
            }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(clock.date, "dddd").toLowerCase()
            font.pixelSize: Style.px(Math.max(Style.small, Math.min(15, root.height * 0.13)))
            color: Colors.mid
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: clock.date.getDate()
            font.pixelSize: Style.px(Math.min(root.height * 0.46, root.width * 0.5))
            font.bold: true
            color: Colors.bright
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(clock.date, "MMMM").toLowerCase()
            font.pixelSize: Style.px(Math.max(Style.small, Math.min(15, root.height * 0.13)))
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: !root.open
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    // ── the month ──
    MonthGrid {
        id: month
        anchors.centerIn: parent
        width: parent.width
        cellHeight: Math.max(16, Math.floor((root.height - 52) / 6))
        closable: true
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 220 : 140
            }
        }
        // back on this month, days popping in, each time it opens
        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    month.offset = 0;
                    month.cascade();
                }
            }
        }
        onTitleClicked: root.toggle()
        onCloseClicked: root.toggle()
    }
}

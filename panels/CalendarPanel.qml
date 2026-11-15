import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Centre panel: a big clock with seconds, and a month you can page through.
Panel {
    id: root
    name: "calendar"
    side: "center"
    panelWidth: 300
    title: "TIME"

    onOpenChanged: if (open)
        month.offset = 0

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.visible
    }

    Column {
        width: parent.width
        spacing: 2
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            font.pixelSize: Style.px(30)
            font.bold: true
            color: Colors.bright
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy").toLowerCase()
            color: Colors.mid
        }
    }

    MonthGrid {
        id: month
        width: parent.width
    }
}

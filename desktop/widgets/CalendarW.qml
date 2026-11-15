import QtQuick
import qs.config
import qs.components

Item {
    id: root
    property var wd

    MonthGrid {
        anchors.centerIn: parent
        width: parent.width
        cellHeight: Math.max(18, Math.floor((root.height - 60) / 6))
    }
}

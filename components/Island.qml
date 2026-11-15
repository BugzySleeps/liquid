import QtQuick
import qs.config
import qs.services

// A floating box (square, round or wavy: see Look) on the bar: black, hairline green border. Its width eases when content changes.
Frame {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth + 2
    implicitHeight: Style.barHeight
    // in the strip (Settings.barStyle) the islands are just groups on one bar: no fill, no outline
    readonly property bool flat: Settings.barStyle === "strip"
    color: flat ? "transparent" : Colors.glass
    border.width: flat ? 0 : Style.line
    border.color: Colors.faint
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Style.slow
            easing.type: Easing.OutExpo
        }
    }

    Row {
        id: row
        x: 1
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}

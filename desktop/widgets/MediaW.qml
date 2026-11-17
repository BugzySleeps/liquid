import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config
import qs.services
import qs.components

// Cover art (tinted), track, a seek line, controls, and a few live bars; small, the art over the controls
// (and the track, if there's room).
Item {
    id: root
    property var wd

    readonly property bool compact: width < Widgets.need("media")[0] || height < Widgets.need("media")[1]

    ColumnLayout {
        anchors.fill: parent
        visible: root.compact
        spacing: 4
        Art {
            Layout.preferredWidth: Math.max(0, Math.min(root.width, root.height - controls.height - (small.visible ? small.height + 4 : 0) - 4))
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignHCenter
            source: Media.art
            sourceSize: 256
            borderColor: Colors.dim
            turning: Media.playing
        }
        Txt {
            id: small
            Layout.fillWidth: true
            visible: root.height >= 150
            horizontalAlignment: Text.AlignHCenter
            text: Media.title || (Media.active ? "—" : "start some music")
            font.bold: !!Media.title
            color: Media.title ? Colors.bright : Colors.mid
        }
        Row {
            id: controls
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            IconBtn {
                icon: "󰒮"
                size: 26
                iconSize: 13
                onClicked: Media.previous()
            }
            IconBtn {
                icon: Media.playing ? "󰏤" : "󰐊"
                armed: true
                size: 26
                iconSize: 13
                onClicked: Media.toggle()
            }
            IconBtn {
                icon: "󰒭"
                size: 26
                iconSize: 13
                onClicked: Media.next()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: !root.compact
        spacing: 14

        Art {
            Layout.preferredWidth: Math.min(root.height, root.width * 0.38)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            source: Media.art
            sourceSize: 256
            borderColor: Colors.dim
            turning: Media.playing
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            Txt {
                Layout.fillWidth: true
                text: Media.title
                font.bold: true
                font.pixelSize: Style.px(13)
                color: Colors.bright
            }
            Txt {
                Layout.fillWidth: true
                text: Media.artist || (Media.active ? "—" : "start some music")
                color: Media.artist ? Colors.accent : Colors.mid
            }
            Item {
                Layout.fillHeight: true
            }
            Visualizer {
                Layout.fillWidth: true
                visible: Media.playing
                height: 18
                bars: 20
                barWidth: Math.max(2, Math.floor((width - 19 * 2) / 20))
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 2
                visible: Media.length > 0
                color: Colors.faint
                Rectangle {
                    height: parent.height
                    width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                    color: Colors.accent
                }
            }
            Row {
                spacing: 4
                IconBtn {
                    icon: "󰒮"
                    size: 26
                    iconSize: 13
                    onClicked: Media.previous()
                }
                IconBtn {
                    icon: Media.playing ? "󰏤" : "󰐊"
                    armed: true
                    size: 26
                    iconSize: 13
                    onClicked: Media.toggle()
                }
                IconBtn {
                    icon: "󰒭"
                    size: 26
                    iconSize: 13
                    onClicked: Media.next()
                }
            }
        }
    }
}

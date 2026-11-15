import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Terminal-style system summary:  bugzy@bugzy  then a tree of facts and live meters.
Item {
    id: root
    property var wd

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // the logo, as tall as the prompt + rule (a drop falls every so often)
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 56
            implicitHeight: 56
            color: Colors.accent
            Logo {
                anchors.centerIn: parent
                width: 46
                height: 46
                color: Colors.bg
                live: !Perf.low
                every: 9000
            }
        }

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            Txt {
                text: Sys.user + "@" + Sys.host
                font.bold: true
                font.pixelSize: Style.px(13)
                color: Colors.bright
            }
            Txt {
                text: "─".repeat(Math.max(4, (Sys.user + "@" + Sys.host).length))
                color: Colors.dim
            }

            Repeater {
                model: [
                    ["os", () => Sys.os],
                    ["kernel", () => Sys.kernel],
                    ["uptime", () => Sys.uptime],
                    ["wm", () => "Hyprland · Quickshell"],
                    ["shell", () => Sys.shell],
                    ["cpu", () => Sys.cpuModel]
                ]
                RowLayout {
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 6
                    Txt {
                        text: index === 5 ? "├" : "├"
                        color: Colors.dim
                    }
                    Txt {
                        Layout.preferredWidth: 46
                        text: modelData[0]
                        color: Colors.mid
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: modelData[1]()
                    }
                }
            }

            Repeater {
                model: [
                    ["load", () => Sys.cpu, () => Math.round(Sys.cpu * 100) + "%"],
                    ["ram", () => Sys.mem, () => Sys.memUsed.toFixed(1) + "G"],
                    ["disk", () => Sys.disk, () => Math.round(Sys.disk * 100) + "%"]
                ]
                RowLayout {
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 6
                    Txt {
                        text: index === 2 ? "└" : "├"
                        color: Colors.dim
                    }
                    Txt {
                        Layout.preferredWidth: 46
                        text: modelData[0]
                        color: Colors.mid
                    }
                    Meter {
                        segments: 16
                        segWidth: 6
                        segHeight: 8
                        value: modelData[1]()
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: modelData[2]()
                        font.pixelSize: Style.small
                    }
                }
            }
        }
    }
}

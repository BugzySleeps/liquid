import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Now (icon, temperature, words, place) and the next three days; small, just now (icon, temperature, hi / lo).
Item {
    id: root
    property var wd

    readonly property string city: (wd?.props.city ?? "").trim()
    // where you are stays off the screen when it's shared or recorded (or always): props.place
    // "show" · "sharing" (the default: hidden while sharing) · "hide"
    readonly property string placeRule: wd?.props.place ?? "sharing"
    readonly property bool hidePlace: placeRule === "hide" || (placeRule === "sharing" && Privacy.sharing)
    readonly property string unit: wd?.props.units === "fahrenheit" ? "°F" : "°C"
    readonly property var w: city ? Weather.data[Weather.key(city, wd.props.units)] : null
    readonly property bool ready: w?.temp !== undefined && !w?.error
    readonly property bool compact: width < Widgets.need("weather")[0] || height < Widgets.need("weather")[1]

    Column {
        anchors.centerIn: parent
        visible: !root.w || !!root.w.error || (!!root.w.loading && root.w.temp === undefined)
        spacing: 4
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰖐"
            font.pixelSize: 28
            color: Colors.dim
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width)
            text: !root.city ? "set a city in edit mode (SUPER+W)" : root.w?.error ?? "loading…"
            color: Colors.mid
            font.pixelSize: Style.small
        }
    }

    // small: now, stacked in the middle
    Column {
        anchors.centerIn: parent
        width: parent.width
        visible: root.ready && root.compact
        spacing: 2
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.icon(root.w?.code ?? 0, root.w?.day)
                font.pixelSize: Math.min(36, root.height * 0.4)
                color: Colors.bright
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.w?.temp ?? "") + root.unit
                font.pixelSize: Style.px(Math.min(26, root.height * 0.3))
                font.bold: true
                color: Colors.bright
            }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Weather.words(root.w?.code ?? 0)
            font.pixelSize: Style.small
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: (root.w?.hi ?? "") + "° / " + (root.w?.lo ?? "") + "°"
            font.pixelSize: Style.small
            color: Colors.mid
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.ready && !root.compact
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Icon {
                text: Weather.icon(root.w?.code ?? 0, root.w?.day)
                font.pixelSize: Math.min(48, root.height * 0.32)
                color: Colors.bright
            }
            Column {
                Layout.fillWidth: true
                Txt {
                    text: (root.w?.temp ?? "") + root.unit
                    font.pixelSize: Style.px(Math.min(30, root.height * 0.2))
                    font.bold: true
                    color: Colors.bright
                }
                Txt {
                    width: parent.width
                    text: Weather.words(root.w?.code ?? 0) + "  ·  " + (root.w?.hi ?? "") + "° / " + (root.w?.lo ?? "") + "°"
                    font.pixelSize: Style.small
                }
                Txt {
                    width: parent.width
                    text: (root.hidePlace ? "󰈉 hidden" : (root.w?.place ?? "").toLowerCase()) + "  ·  󰖝 " + (root.w?.wind ?? "") + " km/h  ·  󰖌 " + (root.w?.humidity ?? "") + "%"
                    font.pixelSize: Style.small
                    color: Colors.mid
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.dim
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Repeater {
                model: root.w?.days ?? []
                Column {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name
                        font.pixelSize: Style.small
                        color: Colors.mid
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.icon(modelData.code, true)
                        font.pixelSize: 16
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.hi + "° " + modelData.lo + "°"
                        font.pixelSize: Style.small
                    }
                }
            }
        }
    }
}

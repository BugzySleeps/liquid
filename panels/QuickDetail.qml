import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.components

// The control centre's details under its toggles (`kind`): the wifi networks, the bluetooth devices, or the
// night light's warmth and hours. Wifi and bluetooth scan while they're open.
Frame {
    id: root

    property string kind: ""

    implicitHeight: col.implicitHeight + 16
    color: Colors.bg1

    Component.onCompleted: {
        if (kind === "wifi")
            Net.scan(true);
        if (kind === "bt")
            Bt.scan(true);
    }
    Component.onDestruction: {
        Net.scan(false);
        Bt.scan(false);
        Net.asking = "";
    }

    Column {
        id: col
        x: 10
        y: 8
        width: parent.width - 20
        spacing: 4

        // ── wifi ──
        Txt {
            visible: root.kind === "wifi"
            text: !Net.enabled ? "wifi is off" : Net.networks.length ? "networks" : "looking for networks…"
            font.pixelSize: Style.small
            font.letterSpacing: 1
            color: Colors.mid
        }
        Repeater {
            model: root.kind === "wifi" && Net.enabled ? Net.networks.slice(0, 8) : []
            Column {
                id: net
                required property var modelData
                property string error: ""
                width: col.width
                spacing: 4

                Connections {
                    target: net.modelData
                    function onConnectionFailed(reason) {
                        net.error = reason === ConnectionFailReason.NoSecrets ? "wrong password" : "couldn't connect";
                        if (reason === ConnectionFailReason.NoSecrets && Net.secured(net.modelData))
                            Net.asking = net.modelData.name;
                    }
                    function onConnectedChanged() {
                        if (net.modelData.connected)
                            net.error = "";
                    }
                }

                Row_ {
                    glyph: Net.bars(net.modelData)
                    name: net.modelData.name
                    on: net.modelData.connected
                    sub: net.modelData.connected ? "connected" : net.modelData.stateChanging ? "connecting…" : net.error ? net.error
                        : Net.enterprise(net.modelData) ? "enterprise: use nmtui" : net.modelData.known ? "saved" : Net.secured(net.modelData) ? "󰌾 locked" : "open"
                    alert: net.error !== ""
                    action: net.modelData.connected ? "disconnect" : Net.enterprise(net.modelData) && !net.modelData.known ? "" : "connect"
                    forget: net.modelData.known
                    onUsed: {
                        net.error = "";
                        Net.use(net.modelData);
                    }
                    onForgot: net.modelData.forget()
                }

                Field {
                    id: pw
                    visible: Net.asking === net.modelData.name
                    width: parent.width
                    secret: true
                    placeholder: "password for " + net.modelData.name + ", then enter"
                    onVisibleChanged: if (visible) {
                        text = "";
                        forceFocus();
                    }
                    onSubmitted: t => {
                        if (Net.asking === net.modelData.name && t !== "") {
                            net.error = "";
                            Net.join(net.modelData, t);
                        }
                    }
                }
            }
        }

        // ── bluetooth ──
        RowLayout {
            visible: root.kind === "bt"
            width: col.width
            Txt {
                Layout.fillWidth: true
                text: !Bt.available ? "bluetooth isn't running" : !Bt.enabled ? "bluetooth is off" : Bt.adapter.discovering ? "devices · looking…" : "devices"
                font.pixelSize: Style.small
                font.letterSpacing: 1
                color: Colors.mid
            }
        }
        Txt {
            visible: root.kind === "bt" && !Bt.available
            width: col.width
            wrapMode: Text.WordWrap
            text: "start its service once and it stays on:\nsudo systemctl enable --now bluetooth"
            font.pixelSize: Style.small
            color: Colors.accent
        }
        Txt {
            visible: root.kind === "bt" && Bt.enabled && Bt.devices.length === 0
            text: "put a device in pairing mode"
            font.pixelSize: Style.small
            color: Colors.dim
        }
        Repeater {
            model: root.kind === "bt" && Bt.enabled ? Bt.devices.slice(0, 8) : []
            Row_ {
                required property var modelData
                width: col.width
                glyph: Bt.glyph(modelData)
                name: modelData.name || modelData.deviceName
                on: modelData.connected
                sub: modelData.pairing ? "pairing…" : modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                    : modelData.connected ? "connected" + (modelData.batteryAvailable ? " · 󰁹 " + Math.round(modelData.battery * 100) + "%" : "")
                    : modelData.paired ? "paired" : "new"
                action: modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair"
                forget: modelData.paired
                onUsed: Bt.use(modelData)
                onForgot: modelData.forget()
            }
        }

        // ── night light ──
        RowLayout {
            visible: root.kind === "night"
            width: col.width
            spacing: 4
            Txt {
                Layout.fillWidth: true
                text: "night light"
                font.pixelSize: Style.small
                font.letterSpacing: 1
                color: Colors.mid
            }
            Repeater {
                model: ["off", "on", "auto"]
                Chip {
                    required property string modelData
                    text: modelData
                    on: Settings.nightMode === modelData
                    onClicked: Settings.set("nightMode", modelData)
                }
            }
        }
        RowLayout {
            visible: root.kind === "night"
            width: col.width
            spacing: 10
            Icon {
                Layout.preferredWidth: 18
                text: "󰔏"
            }
            SegSlider {
                Layout.fillWidth: true
                segments: 20
                // 6000 K (barely) … 2500 K (candle)
                value: (6000 - Settings.nightTemp) / 3500
                onMoved: v => Settings.set("nightTemp", Math.round((6000 - v * 3500) / 100) * 100)
            }
            Txt {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: Settings.nightTemp + "K"
            }
        }
        RowLayout {
            visible: root.kind === "night"
            width: col.width
            spacing: 4
            opacity: Settings.nightMode === "auto" ? 1 : 0.5
            Txt {
                Layout.fillWidth: true
                text: "auto: from"
                font.pixelSize: Style.small
                color: Colors.mid
            }
            Hour {
                key: "nightFrom"
            }
            Txt {
                text: "to"
                font.pixelSize: Style.small
                color: Colors.mid
            }
            Hour {
                key: "nightTo"
            }
        }
    }

    // a network or a device: glyph, name, a status line; click to use it, × to forget it
    component Row_: Rectangle {
        id: row
        property string glyph
        property string name
        property string sub
        property string action
        property bool on
        property bool alert
        property bool forget
        signal used
        signal forgot

        width: parent?.width ?? 0
        height: 34
        color: rowArea.containsMouse ? Colors.bg2 : "transparent"
        Rectangle {
            visible: row.on
            width: 2
            height: parent.height
            color: Colors.accent
        }
        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.action ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (row.action)
                row.used()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            spacing: 8
            Icon {
                Layout.preferredWidth: 18
                text: row.glyph
                font.pixelSize: 15
                color: row.on ? Colors.bright : Colors.accent
            }
            Column {
                Layout.fillWidth: true
                Txt {
                    width: parent.width
                    text: row.name
                    elide: Text.ElideRight
                    font.bold: row.on
                    color: row.on ? Colors.bright : Colors.accent
                }
                Txt {
                    width: parent.width
                    text: row.sub
                    elide: Text.ElideRight
                    font.pixelSize: Style.small
                    color: row.alert ? Colors.alert : Colors.mid
                }
            }
            Txt {
                visible: rowArea.containsMouse && row.action !== ""
                text: row.action
                font.pixelSize: Style.small
                color: Colors.bright
            }
            Icon {
                visible: row.forget && rowArea.containsMouse
                text: "󰅖"
                font.pixelSize: 12
                color: forgetArea.containsMouse ? Colors.alert : Colors.mid
                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.forgot()
                }
            }
        }
    }

    // an hour of the day: click for later, right-click for earlier, or scroll
    component Hour: Chip {
        id: hour
        property string key
        text: String(Settings[key]).padStart(2, "0") + ":00"
        on: Settings.nightMode === "auto"
        function nudge(d) {
            Settings.set(key, (Settings[key] + d + 24) % 24);
        }
        onClicked: nudge(1)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: hour.nudge(-1)
            onWheel: w => hour.nudge(w.angleDelta.y > 0 ? 1 : -1)
        }
    }
}

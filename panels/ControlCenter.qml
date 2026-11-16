import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Right panel: who/uptime, toggles (wifi, bluetooth and night light open their details under them), power
// profiles, sliders, system meters, notifications, power.
Panel {
    id: root
    name: "control"
    side: "right"
    panelWidth: 380
    title: "CONTROL"

    // power buttons need a second click within 3s
    property string armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    onOpenChanged: {
        if (open) {
            Power.check();
        } else {
            armed = "";
            Ui.quick = "";
        }
    }

    // which toggle's details are open under them (Ui.quick): "" · wifi · bt · night
    function expand(what) {
        Ui.quick = Ui.quick === what ? "" : what;
    }

    function power(what, cmd) {
        if (armed !== what) {
            armed = what;
            disarm.restart();
            return;
        }
        armed = "";
        Ui.panel = "";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // ── who ──────────────────────────────────────────────
    RowLayout {
        width: parent.width
        spacing: 10
        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: Look.round ? 18 : 0
            color: Colors.accent
            Logo {
                anchors.centerIn: parent
                width: 28
                height: 28
                color: Colors.bg
                onVisibleChanged: if (visible)
                    drip()
            }
        }
        Column {
            Layout.fillWidth: true
            Txt {
                text: Sys.user + "@" + Sys.host
                font.bold: true
                color: Colors.bright
            }
            Txt {
                text: "up " + Sys.uptime
                color: Colors.mid
                font.pixelSize: Style.small
            }
        }
        IconBtn {
            icon: "󰒓"
            onClicked: {
                Ui.panel = "";
                Settings.open = true;
            }
        }
        IconBtn {
            icon: "󰏘"
            onClicked: {
                Ui.openPicker();
            }
        }
    }

    // ── toggles ──────────────────────────────────────────
    GridLayout {
        width: parent.width
        columns: 2
        rowSpacing: 6
        columnSpacing: 6
        Tile {
            Layout.fillWidth: true
            icon: Net.icon
            label: "wifi"
            status: Net.name
            on: Net.enabled
            more: true
            expanded: Ui.quick === "wifi"
            onClicked: Net.toggle()
            onExpand: root.expand("wifi")
        }
        Tile {
            Layout.fillWidth: true
            icon: Bt.icon
            label: "bluetooth"
            status: Bt.status
            on: Bt.enabled
            more: true
            expanded: Ui.quick === "bt"
            onClicked: Bt.available ? Bt.toggle() : root.expand("bt")
            onExpand: root.expand("bt")
        }
        Tile {
            Layout.fillWidth: true
            icon: Audio.muted ? "󰖁" : "󰕾"
            label: "sound"
            status: Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
            on: !Audio.muted
            onClicked: Audio.toggleMute()
        }
        Tile {
            Layout.fillWidth: true
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            label: "mic"
            status: Audio.micMuted ? "muted" : "live"
            on: !Audio.micMuted
            onClicked: Audio.toggleMic()
        }
        Tile {
            Layout.fillWidth: true
            icon: Ui.dnd ? "󰂛" : "󰂚"
            label: "quiet"
            status: Ui.dnd ? "no popups" : "popups on"
            on: Ui.dnd
            onClicked: Ui.dnd = !Ui.dnd
        }
        Tile {
            Layout.fillWidth: true
            icon: Night.active ? "󰖔" : "󰖙"
            label: "night light"
            status: Settings.nightMode === "auto" ? (Night.active ? "auto · on" : "auto · from " + String(Settings.nightFrom).padStart(2, "0") + ":00") : Night.active ? Settings.nightTemp + "K" : "off"
            on: Night.active
            more: true
            expanded: Ui.quick === "night"
            onClicked: Night.toggle()
            onExpand: root.expand("night")
        }
    }

    Loader {
        width: parent.width
        active: Ui.quick !== ""
        visible: active
        sourceComponent: QuickDetail {
            kind: Ui.quick
        }
    }

    // ── power profile ──
    RowLayout {
        width: parent.width
        spacing: 4
        Icon {
            Layout.preferredWidth: 22
            text: Power.available ? Power.icons[Power.profile] : "󰾅"
            font.pixelSize: 15
        }
        Txt {
            Layout.fillWidth: true
            text: Power.available ? "power" : "power profiles need power-profiles-daemon"
            elide: Text.ElideRight
            color: Colors.mid
            font.pixelSize: Power.available ? Style.text : Style.small
        }
        Repeater {
            model: Power.available ? [0, 1, 2] : []
            Chip {
                required property int modelData
                visible: modelData !== 2 || Power.hasPerformance
                text: Power.icons[modelData] + " " + Power.names[modelData]
                on: Power.profile === modelData
                onClicked: Power.set(modelData)
            }
        }
    }

    // ── shape: square / round / squiggle (everything, windows too) ──
    RowLayout {
        width: parent.width
        spacing: 4
        Icon {
            Layout.preferredWidth: 22
            text: Look.wavy ? "󰏰" : Look.round ? "󰄰" : "󰝤"
            font.pixelSize: 15
        }
        Txt {
            Layout.fillWidth: true
            text: "shape"
            color: Colors.mid
        }
        Repeater {
            model: [["󰝤", "square"], ["󰄰", "round"], ["󰏰", "squiggle"]]
            Chip {
                required property var modelData
                text: modelData[0] + " " + modelData[1]
                on: Look.shape === modelData[1]
                onClicked: Look.set(modelData[1])
            }
        }
    }
    RowLayout {
        width: parent.width
        spacing: 4
        Icon {
            Layout.preferredWidth: 22
            text: "󰂵"
            font.pixelSize: 15
        }
        Txt {
            Layout.fillWidth: true
            text: "glass"
            color: Colors.mid
        }
        Chip {
            text: "off"
            on: !Look.glass
            onClicked: Look.setGlass(false)
        }
        Chip {
            text: "󰂵 liquid glass"
            on: Look.glass
            onClicked: Look.setGlass(true)
        }
    }

    // ── sliders ──────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 8
        Repeater {
            model: [
                { icon: () => Audio.icon, value: () => Audio.volume, set: v => Audio.setVolume(v), show: true },
                { icon: () => "󰃟", value: () => Bright.value, set: v => Bright.set(v), show: Bright.available }
            ]
            RowLayout {
                required property var modelData
                visible: modelData.show
                width: parent.width
                spacing: 10
                Icon {
                    Layout.preferredWidth: 18
                    text: modelData.icon()
                }
                SegSlider {
                    Layout.fillWidth: true
                    segments: 24
                    value: modelData.value()
                    onMoved: v => modelData.set(v)
                }
                Txt {
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(modelData.value() * 100) + "%"
                }
            }
        }
    }

    // ── system ───────────────────────────────────────────
    Frame {
        width: parent.width
        height: stats.implicitHeight + 16
        color: Colors.bg1
        Column {
            id: stats
            x: 10
            y: 8
            width: parent.width - 20
            spacing: 6
            Repeater {
                model: [
                    { icon: "󰘚", label: "cpu", value: () => Sys.cpu, text: () => Math.round(Sys.cpu * 100) + "%" },
                    { icon: "󰍛", label: "ram", value: () => Sys.mem, text: () => Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB" },
                    { icon: "󰋊", label: "disk", value: () => Sys.disk, text: () => Sys.diskText }
                ]
                RowLayout {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Icon {
                        Layout.preferredWidth: 16
                        text: modelData.icon
                        font.pixelSize: 13
                    }
                    Txt {
                        Layout.preferredWidth: 30
                        text: modelData.label
                        color: Colors.mid
                    }
                    Meter {
                        segments: 14
                        segWidth: 6
                        segHeight: 8
                        value: modelData.value()
                    }
                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: modelData.text()
                        font.pixelSize: Style.small
                    }
                }
            }
        }
    }

    // ── notes: the scratchpad (the same text as note widgets set to scratchpad) ──
    Frame {
        width: parent.width
        height: 96
        color: Colors.bg1
        Txt {
            x: 10
            y: 7
            text: "notes"
            font.pixelSize: Style.small
            font.letterSpacing: 1
            color: Colors.mid
        }
        Flickable {
            id: notesFlick
            x: 10
            y: 24
            width: parent.width - 20
            height: parent.height - 30
            contentHeight: notes.implicitHeight
            clip: true
            TextEdit {
                id: notes
                width: notesFlick.width
                wrapMode: TextEdit.Wrap
                color: Colors.accent
                selectionColor: Colors.accent
                selectedTextColor: Colors.bg
                font.family: Style.font
                font.pixelSize: Style.text
                Component.onCompleted: text = Widgets.scratch
                onTextChanged: if (activeFocus)
                    notesSave.restart()
                Connections {
                    target: Widgets
                    function onScratchChanged() {
                        if (!notes.activeFocus && notes.text !== Widgets.scratch)
                            notes.text = Widgets.scratch;
                    }
                }
                Keys.onEscapePressed: Ui.panel = ""
            }
            Txt {
                visible: notes.text === "" && !notes.activeFocus
                text: "click to jot something down"
                color: Colors.dim
            }
            MouseArea {
                anchors.fill: parent
                visible: !notes.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: notes.forceActiveFocus()
            }
        }
        Timer {
            id: notesSave
            interval: 500
            onTriggered: Widgets.setScratch(notes.text)
        }
    }

    // ── notifications (panels/NotifCentre.qml) ───────────
    NotifCentre {
        width: parent.width
    }

    // ── power ────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 6
        RowLayout {
            width: parent.width
            spacing: 6
            Repeater {
                model: [
                    { id: "lock", icon: "󰌾", cmd: "~/.config/rice/rice lock" },
                    { id: "sleep", icon: "󰒲", cmd: "systemctl suspend" },
                    { id: "logout", icon: "󰍃", cmd: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
                    { id: "reboot", icon: "󰜉", cmd: "systemctl reboot" },
                    { id: "off", icon: "󰐥", cmd: "systemctl poweroff" }
                ]
                IconBtn {
                    required property var modelData
                    Layout.fillWidth: true
                    size: 34
                    icon: modelData.icon
                    armed: root.armed === modelData.id
                    onClicked: root.power(modelData.id, modelData.cmd)
                }
            }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Style.small
            color: root.armed ? Colors.bright : Colors.dim
            text: root.armed ? "click " + root.armed + " again" : "lock · sleep · log out · reboot · power off"
        }
    }
}

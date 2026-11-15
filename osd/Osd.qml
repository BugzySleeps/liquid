import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// Volume / brightness: a vial of liquid at the right edge that fills to the level and sloshes when it
// changes. Click-through.
PanelWindow {
    id: win

    property string icon: ""
    property real value: 0
    property bool showing: false
    property bool armed: false      // ignore the values settling right after start

    function show(i, v) {
        if (!armed || Ui.panel === "control" || Settings.osdStyle !== "vial")
            return;
        icon = i;
        value = v;
        showing = true;
        Sounds.play("tick");
        hide.restart();
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: win.armed = true
    }
    Timer {
        id: hide
        interval: 1400
        onTriggered: win.showing = false
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            win.show(Audio.icon, Audio.volume);
        }
        function onMutedChanged() {
            win.show(Audio.icon, Audio.muted ? 0 : Audio.volume);
        }
    }
    Connections {
        target: Bright
        function onValueChanged() {
            win.show("󰃟", Bright.value);
        }
    }

    property real t: showing ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }

    screen: Ui.screen
    visible: t > 0
    color: "transparent"
    exclusiveZone: 0
    anchors.right: true
    margins.right: 22
    implicitWidth: 64
    implicitHeight: 250
    mask: Region {}
    WlrLayershell.namespace: "ekitai-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    Frame {
        width: parent.width
        height: parent.height
        x: (1 - win.t) * 24
        opacity: win.t
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            spacing: 10

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(win.value * 100)
                font.bold: true
                font.pixelSize: Style.px(13)
                color: Colors.bright
            }
            Vial {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26
                height: 160
                level: win.value
                alive: win.showing
            }
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.icon
                font.pixelSize: 17
            }
        }
    }
}

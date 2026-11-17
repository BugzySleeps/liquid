import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.config
import qs.components

// A picture from a path (set in edit mode). Tinted into the one green unless that's turned off.
Item {
    id: root
    property var wd

    readonly property string path: {
        const p = (wd?.props.path ?? "").trim();
        return p.startsWith("~") ? Quickshell.env("HOME") + p.slice(1) : p;
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.path ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: Math.max(256, root.width * 2)
        layer.enabled: root.wd?.props.tint ?? true
        layer.effect: Colorize {
            hue: Math.max(0, Colors.accent.hslHue)
            saturation: Colors.accent.hslSaturation < 0.05 ? 0 : 0.75   // a grey theme has no hue: grey, not red
            lightness: -0.05
        }
    }

    Column {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        spacing: 6
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰋩"
            font.pixelSize: 32
            color: Colors.dim
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !root.path ? "set a path in edit mode" : img.status === Image.Error ? "can't open that file" : "loading…"
            font.pixelSize: Style.small
            color: Colors.mid
        }
    }
}

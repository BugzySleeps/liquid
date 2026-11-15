import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// The wallpaper (the theme sets wallpaper_by_shell, so this replaces hyprpaper). A new one wipes up
// from the bottom over the old, behind a thin line in the new accent, the way windows open.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Colors.bg
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "ekitai-wallpaper"

            // `top` shows the wallpaper; for a change, the old one moves to `under`, then the new one
            // loads into `top` and wipes up over it
            property string shown: ""
            readonly property string next: Colors.wallpaper
            property string stage: ""                // "" · "under" (old moving down) · "load" (new loading) · "wipe"
            property real p: 1                       // how much of `top` shows, from the bottom
            property string loading: ""              // the path going into `top`

            onNextChanged: change()
            Component.onCompleted: change()

            function change() {
                if (!next || next === shown || stage)
                    return;
                loading = next;
                if (!shown) {                        // the first one: just show it
                    stage = "load";
                    top.source = "file://" + next;
                    return;
                }
                stage = "under";
                under.source = "file://" + shown;
                underReady();
            }

            function underReady() {
                if (stage !== "under" || under.status !== Image.Ready)
                    return;
                p = 0;
                stage = "load";
                top.source = "file://" + next;
            }

            function topReady() {
                if (stage !== "load" || top.status !== Image.Ready)
                    return;
                if (!shown) {
                    p = 1;
                    done();
                } else {
                    stage = "wipe";
                    settle.restart();
                }
            }

            function done() {
                shown = loading;
                stage = "";
                change();                            // it changed again meanwhile
            }

            // rice is still reloading hyprland and the terminals when the palette lands; let that pass first
            Timer {
                id: settle
                interval: 150
                onTriggered: {
                    Colors.go();                     // the new colours fade in as it wipes up
                    wipe.restart();
                }
            }

            NumberAnimation {
                id: wipe
                target: win
                property: "p"
                from: 0
                to: 1
                duration: Colors.duration
                easing.type: Easing.InOutCubic
                onFinished: win.done()
            }

            Image {
                id: under
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: win.width
                sourceSize.height: win.height
                asynchronous: true
                onStatusChanged: win.underReady()
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * win.p
                clip: true

                Image {
                    id: top
                    anchors.bottom: parent.bottom
                    width: win.width
                    height: win.height
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: win.width
                    sourceSize.height: win.height
                    asynchronous: true
                    onStatusChanged: win.topReady()
                }
            }

            // the edge of the wipe
            Rectangle {
                visible: wipe.running
                y: parent.height * (1 - win.p) - 1
                width: parent.width
                height: 2
                color: Colors.accent
                opacity: Math.sin(win.p * Math.PI)
            }
        }
    }
}

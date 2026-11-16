import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The idle tide (services/Tide.qml): the lock screen's liquid rising over the desktop on every screen.
// Each screen is captured once as the tide starts, so the liquid bends your real windows; above the surface
// it's see-through. It never takes the mouse or keys: touching anything is what drains it.
Variants {
    model: Quickshell.screens

    LazyLoader {
        id: loader
        required property var modelData
        active: Tide.shown

        PanelWindow {
            screen: loader.modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "ekitai-tide"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: view
                anchors.fill: parent

                property real time: 0
                FrameAnimation {
                    running: true
                    onTriggered: view.time += frameTime
                }

                // coming back: a ripple where it's draining from
                property vector4d r0: Qt.vector4d(0, -99, 0, 0)
                property vector4d r1: Qt.vector4d(0, -99, 0, 0)
                Connections {
                    target: Tide
                    function onKickChanged() {
                        view.r0 = Qt.vector4d(view.width * (0.3 + Math.random() * 0.4), view.time, 1.2, 0);
                        view.r1 = Qt.vector4d(view.width * Math.random(), view.time + 0.15, 0.7, 0);
                    }
                }

                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: loader.modelData
                    live: false
                }

                ShaderEffect {
                    anchors.fill: parent              // (before the capture lands it's just dark liquid)
                    property variant source: ShaderEffectSource {
                        sourceItem: shot
                        hideSource: true
                    }
                    property size size: Qt.size(width, height)
                    property real time: view.time
                    property real level: Tide.level
                    property real rough: Tide.phase === "falling" ? 0.6 : 0.15 + Tide.level * 0.3
                    property color tint: Colors.accent
                    property color glow: Colors.bright
                    property color deep: Colors.bg
                    property vector4d r0: view.r0
                    property vector4d r1: view.r1
                    property vector4d r2: Qt.vector4d(0, -99, 0, 0)
                    property vector4d r3: Qt.vector4d(0, -99, 0, 0)
                    property vector4d r4: Qt.vector4d(0, -99, 0, 0)
                    property vector4d r5: Qt.vector4d(0, -99, 0, 0)
                    property vector4d r6: Qt.vector4d(0, -99, 0, 0)
                    property vector4d r7: Qt.vector4d(0, -99, 0, 0)
                    property real clear: 1               // see-through above the surface
                    fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
                }
            }
        }
    }
}

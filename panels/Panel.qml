import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// A box that unrolls downward from under the bar. Opens when Ui.panel === name; a click
// anywhere else (except the bar) or Esc closes it.
PanelWindow {
    id: win

    required property string name
    property string side: "center"     // left | center | right
    property int panelWidth: 360
    property string title: ""
    property Component backdrop: null   // drawn under everything, filling the box (cut to its shape)
    default property alias content: body.data

    readonly property bool open: Ui.panel === name

    property real t: open ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: win.open ? Style.slow : Style.med
            easing.type: win.open ? Easing.OutExpo : Easing.InCubic
        }
    }

    screen: Ui.screen
    visible: t > 0
    color: "transparent"
    exclusiveZone: 0
    anchors {
        top: true
        left: side === "left"
        right: side === "right"
    }
    margins {
        top: Style.gap
        left: Style.edge
        right: Style.edge
    }
    implicitWidth: panelWidth
    // the window stays the screen's height and only the box takes clicks: if it followed the box, every
    // change inside (a notification leaving, details opening) would resize the surface frame by frame,
    // and Hyprland redoing that each frame is what stutters
    implicitHeight: Math.max(frame.height + 2, (screen?.height ?? 900) - Glass.reserved - Style.gap)
    mask: Region {
        item: reveal
    }

    WlrLayershell.namespace: "ekitai-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: win.open
        windows: [win, ...Ui.bars]
        onCleared: Ui.grabCleared(win.name)
    }

    // the reveal: a clip that grows from the top, and a line that draws across first
    Item {
        id: reveal
        width: parent.width
        height: frame.height * win.t
        clip: true

        Frame {
            id: frame
            width: parent.width
            height: body.implicitHeight + Style.pad * 2 + (win.title ? 26 : 0)
            color: Colors.glass
            border.width: Style.line
            border.color: Colors.faint

            Item {
                anchors.fill: parent
                anchors.margins: Look.wavy ? 3 : 1
                visible: win.backdrop !== null
                layer.enabled: Look.round
                layer.effect: OpacityMask {
                    maskSource: backMask
                }
                Loader {
                    anchors.fill: parent
                    sourceComponent: win.backdrop
                }
            }
            Rectangle {
                id: backMask
                anchors.fill: parent
                anchors.margins: Look.wavy ? 3 : 1
                visible: false
                layer.enabled: true
                radius: Math.max(0, Look.r(width, height) - 2)
            }

            Item {
                id: keys
                focus: win.open
                Keys.onEscapePressed: Ui.panel = ""
            }

            // a small title tab: ── 液 control ──
            Row {
                visible: win.title !== ""
                x: Style.pad
                y: 9
                spacing: 8
                Rectangle {
                    width: 6
                    height: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.accent
                }
                Text {
                    text: win.title
                    color: Colors.mid
                    font.family: Style.font
                    font.pixelSize: Style.small
                    font.letterSpacing: 2
                }
            }

            Column {
                id: body
                x: Style.pad
                y: Style.pad + (win.title ? 20 : 0)
                width: parent.width - Style.pad * 2
                spacing: 12
                opacity: Math.max(0, win.t * 2 - 1)
            }
        }
    }

    // the leading edge: a bright line that rides the bottom of the box while it unrolls
    Rectangle {
        visible: win.t > 0 && win.t < 1
        y: frame.height * win.t - 1
        width: parent.width
        height: 2
        color: Colors.bright
    }
}

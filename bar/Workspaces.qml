import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Workspace dots: dim = empty, brighter = has windows, and the active one stretches into a long pill.
// The widths ease, so the pill glides from one to the next. Click a dot to go there, scroll to step,
// right-click for the overview of every workspace.
Item {
    id: root

    readonly property int size: 8
    readonly property int wide: 26
    readonly property int gap: 6
    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int count: Math.max(5, activeId, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))

    implicitWidth: row.implicitWidth + 20
    implicitHeight: Style.barHeight - 2

    Row {
        id: row
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: root.count
            Frame {
                id: dot
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                readonly property bool occupied: (ws?.toplevels.values.length ?? 0) > 0
                readonly property bool active: wsId === root.activeId

                pill: true
                width: active ? root.wide : root.size
                height: root.size
                color: ws?.urgent ? Colors.alert : active ? Colors.accent : hover.containsMouse ? Colors.mid : occupied ? Colors.dim : Colors.faint
                Behavior on width {
                    NumberAnimation {
                        duration: Style.med
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Style.fast
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (m.button === Qt.RightButton)
                            Ui.overview = true;
                        else
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${dot.wsId} })`);
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => Hyprland.dispatch(`hl.dsp.focus({ workspace = "${e.angleDelta.y > 0 ? "-1" : "+1"}" })`)
    }
}

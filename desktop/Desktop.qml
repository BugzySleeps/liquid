import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The desktop layer: widgets sit above the wallpaper and below windows (Board.qml). In edit mode
// (SUPER+W, or right-click the desktop) it rises above windows, dims them, and shows the snap grid.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: desk
            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            readonly property bool editing: Widgets.editing && Widgets.board === "desktop"
            WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Bottom
            WlrLayershell.namespace: "ekitai-desktop"
            WlrLayershell.keyboardFocus: editing || Widgets.typing !== "" || (Widgets.menuOpen && Widgets.menuBoard === "desktop") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Board {
                id: deskBoard
                anchors.fill: parent
                board: "desktop"
                screenName: desk.modelData.name
                first: desk.modelData === Quickshell.screens[0]
                focus: true
                Keys.onEscapePressed: deskBoard.back()
            }
        }
    }
}

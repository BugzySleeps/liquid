import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The lock screen: a real Wayland session lock while Lock.locked (on every screen), or the same view
// in a plain overlay for `qs -c ekitai ipc call lock preview`.
Scope {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface
            color: Colors.bg
            LockView {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
            }
        }
    }

    LazyLoader {
        active: Lock.preview
        PanelWindow {
            screen: Ui.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Colors.bg
            WlrLayershell.namespace: "ekitai-lockpreview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            LockView {
                anchors.fill: parent
                screenName: Ui.screen?.name ?? ""
            }
        }
    }
}

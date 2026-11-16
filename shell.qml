//@ pragma IconTheme breeze-dark
// ekitai (液体) — a Quickshell shell for the `ekitai-qs` rice. Colours come from config/Colors.qml,
// which `rice` regenerates from the theme. IPC entry points are listed in services/Ui.qml.
import QtQuick
import Quickshell
import qs.services
import qs.bar
import qs.desktop
import qs.panels
import qs.launcher
import qs.notifs
import qs.osd
import qs.picker
import qs.lock
import qs.switcher
import qs.screenshot
import qs.settings
import qs.welcome

ShellRoot {
    // services that listen for things themselves are only created when first used; start these now
    // (Sounds: the terminal sounds and the unlock bubble; Tide: watching for idle; Night: the night light's schedule)
    readonly property var listening: [Sounds, Tide, Night, Themes]

    // no "config reloaded" popup after a successful edit (a failed reload still shows its error)
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
    }

    Wallpaper {}
    Desktop {}
    Bar {}
    DynamicIsland {}

    ControlCenter {}
    MediaPanel {}
    CalendarPanel {}

    Launcher {}
    ClipPicker {}
    WindowSwitcher {}
    Overview {}
    ShotEditor {}
    SettingsApp {}
    WallPicker {}
    LockScreen {}
    IdleTide {}
    Toasts {}
    Osd {}
    Welcome {}
}

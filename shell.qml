//@ pragma IconTheme breeze-dark
// ekitai (液体) — a Quickshell shell for the `ekitai-qs` rice. Colours come from config/Colors.qml,
// which `rice` regenerates from the theme. IPC entry points are listed in services/Ui.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
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

    WindowSwitcher {}                            // (always: Alt-Tab has to be instant)

    // the big ones are only built while open (components/Lazy.qml), and their ipc lives here, so it answers
    // while they're not
    Lazy {
        want: Ui.launcher
        Launcher {}
    }
    Lazy {
        want: Clip.open
        ClipPicker {}
    }
    Lazy {
        want: Settings.open
        SettingsApp {}
    }
    Lazy {
        want: Ui.overview
        Overview {}
    }
    IpcHandler {
        target: "overview"
        function toggle(): void {
            Ui.overview = !Ui.overview;
        }
        function open(): void {
            Ui.overview = true;
        }
        function close(): void {
            Ui.overview = false;
        }
    }
    Lazy {
        want: Ui.picker
        WallPicker {}
    }
    IpcHandler {
        target: "wall"
        function toggle(): void {
            Ui.picker ? Ui.picker = false : Ui.openPicker();
        }
    }
    // the screenshot editor opens itself (shot edit <file>): built for that, kept while it's open
    Lazy {
        id: shot
        ShotEditor {}
    }
    IpcHandler {
        target: "shot"
        function edit(path: string): void {
            shot.want = true;
            shot.item.edit(path);
            shot.want = false;
        }
        function save(): void {                  // what Enter does: save + copy
            if (shot.item?.open)
                shot.item.finish(true, true);
        }
        function discard(): void {
            if (shot.item?.open)
                shot.item.discard();
        }
    }
    LockScreen {}
    IdleTide {}
    Toasts {}
    Osd {}
    // the welcome tour: only on the very first start (no ~/.local/state/ekitai/welcomed yet), or when asked
    Lazy {
        id: welcome
        Welcome {}
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/ekitai/welcomed"
        printErrors: false
        onLoadFailed: {                          // never welcomed: build it, and it shows itself
            welcome.want = true;
            welcome.want = false;
        }
    }
    IpcHandler {
        target: "welcome"
        function open(): void {                  // (not "show": that's one of qs ipc's own words)
            welcome.want = true;
            welcome.item.show();
            welcome.want = false;
        }
        function close(): void {
            if (welcome.item)
                welcome.item.open = false;
        }
        function step(n: int): void {            // jump to a step (0-3), for a look
            welcome.want = true;
            welcome.item.go(n);
            welcome.want = false;
        }
    }
}

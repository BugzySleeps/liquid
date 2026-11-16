pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state (lock/LockScreen.qml draws it). The password is checked through PAM's
// "login" stack, the same as hyprlock.
// While locked, ~/.local/state/rice/locked exists: if the shell crashes, Hyprland keeps the session
// locked, and the restarted shell sees the file and locks again (misc.allow_session_lock_restore).
// `rice lock` (SUPER+Escape, and at login) creates the file first, so the shell locks as it starts.
//   qs -c ekitai ipc call lock lock
//   qs -c ekitai ipc call lock isLocked
//   qs -c ekitai ipc call lock preview          the same screen in a normal window, for a look (Esc)
//   qs -c ekitai ipc call lock edit             the preview, editing its widgets (never on the real lock)
// There is deliberately no ipc unlock.
Singleton {
    id: root

    property bool locked: false
    property bool preview: false
    property string buffer: ""
    property string phase: ""                    // "" · "checking" · "fail" · "welcome"
    property int fails: 0
    property bool boot: false                    // the first lock of the session: the lock screen plays its intro
    property bool flooded: false                 // the idle tide filled the screen: the lock screen starts full
    property date since: new Date()

    readonly property string flag: Quickshell.env("HOME") + "/.local/state/rice/locked"

    // music sounds underwater while the lock screen's up (Settings.lockMuffle): ~/.config/rice/eq muffle
    readonly property bool shown: locked || preview
    property bool muffled: false
    onShownChanged: {
        if (shown && Settings.lockMuffle && Media.playing && !muffled) {
            muffled = true;
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rice/eq", "muffle"]);
        } else if (!shown && muffled) {
            muffled = false;
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rice/eq", "unmuffle"]);
        }
    }

    signal failed
    signal leave                                 // play the unlock animation; the screen calls finish()

    function lock(atBoot, byTide) {
        if (locked)
            return;
        boot = !!atBoot;
        flooded = !!byTide && !boot;
        buffer = "";
        phase = "";
        fails = 0;
        since = new Date();
        preview = false;
        if (Widgets.board === "lock")
            Widgets.editing = false;
        locked = true;
        Quickshell.execDetached(["sh", "-c", `mkdir -p "$(dirname "$1")" && touch "$1"`, "sh", flag]);   // touch: keeps a "boot" mark
    }

    function submit() {
        if (phase === "checking" || phase === "welcome" || buffer === "")
            return;
        phase = "checking";
        if (preview) {                           // the preview never touches PAM
            fakeCheck.restart();
            return;
        }
        if (!pam.start())
            fail();
    }

    function fail() {
        phase = "fail";
        fails++;
        buffer = "";
        failed();
    }

    // the lock screen in a normal window, for a look (Esc); `intro`: opening with the login intro
    function openPreview(intro, byTide) {
        if (locked)
            return;
        buffer = "";
        phase = "";
        since = new Date();
        boot = !!intro;
        flooded = !!byTide && !boot;
        preview = true;
    }

    // the lock preview with its widgets in edit mode (the real lock can't be edited)
    function openEditor() {
        if (locked)
            return;
        buffer = "";
        phase = "";
        since = new Date();
        flooded = false;
        preview = true;
        Widgets.board = "lock";
        Widgets.editing = true;
    }

    function finish() {
        if (preview) {
            preview = false;
            if (Widgets.board === "lock")
                Widgets.editing = false;
        } else {
            locked = false;
            Quickshell.execDetached(["rm", "-f", flag]);
        }
        buffer = "";
        phase = "";
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired)
                respond(root.buffer);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "welcome";
                root.buffer = "";
                root.leave();
            } else {
                root.fail();
            }
        }
        onError: root.fail()
    }

    Timer {
        id: fakeCheck
        interval: 700
        onTriggered: {
            if (root.buffer === "fail") {        // type "fail" in the preview to see the wrong-password shake
                root.fail();
            } else {
                root.phase = "welcome";
                root.buffer = "";
                root.leave();
            }
        }
    }

    // locked when the shell starts (a crash, or `rice lock` at login): lock again straight away
    Process {
        running: true
        command: ["sh", "-c", '[ -e "$1" ] && cat "$1"', "sh", root.flag]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "" || started.ok)
                root.lock(text.trim() === "boot")
        }
        onExited: code => started.ok = code === 0
    }
    QtObject {
        id: started
        property bool ok: false
        onOkChanged: if (ok && !root.locked)
            root.lock(false)
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            root.lock(false);
        }
        function boot(): void {                  // at login (rice lock --boot): with the intro
            root.lock(true);
        }
        function isLocked(): bool {
            return root.locked;
        }
        // for testing the preview without sending real keystrokes: type text, or "\n" for Enter.
        // Does nothing unless the preview is open (never the real lock).
        function previewType(text: string): void {
            if (!root.preview || root.locked)
                return;
            if (text === "\\n")
                root.submit();
            else
                root.buffer += text;
        }
        function edit(): void {
            root.openEditor();
        }
        function previewIntro(): void {          // the preview, opening with the login intro
            root.openPreview(true);
        }
        function preview(): void {
            if (root.preview)
                root.preview = false;
            else
                root.openPreview(false);
        }
    }
}

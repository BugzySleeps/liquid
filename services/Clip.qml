pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history (SUPER+SHIFT+V opens it, launcher/ClipPicker.qml). wl-paste --watch says when
// something is copied; text and images are kept, newest first. It lives in $XDG_RUNTIME_DIR
// (memory, gone on reboot), and anything a password manager marks as a password is never kept.
//   qs -c ekitai ipc call clipboard toggle
Singleton {
    id: root

    property bool open: false
    property var items: []                        // [{ kind: "text"|"image", text, path, time }]
    readonly property int max: 60
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/ekitai-clipboard"

    // every copy prints a line; then fetch what it was
    Process {
        running: true
        command: ["wl-paste", "--watch", "echo"]
        stdout: SplitParser {
            onRead: fetch.go()
        }
    }

    Process {
        id: fetch
        property bool again: false
        function go() {
            if (running)
                again = true;
            else
                running = true;
        }
        command: ["sh", "-c", `
            t=$(wl-paste --list-types 2>/dev/null) || exit 0
            printf '%s\\n' "$t" | grep -q 'x-kde-passwordManagerHint' && exit 0     # a password: never kept
            mkdir -p "$1"
            if printf '%s\\n' "$t" | grep -q '^image/'; then
                f="$1/$(date +%s%N).png"
                wl-paste --type image/png > "$f" 2>/dev/null && [ -s "$f" ] && printf 'image\\n%s' "$f"
            else
                printf 'text\\n'; wl-paste --no-newline 2>/dev/null | head -c 65536
            fi`, "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
        onExited: if (again) {
            again = false;
            running = true;
        }
    }

    function take(out) {
        const nl = out.indexOf("\n");
        if (nl < 0)
            return;
        const kind = out.slice(0, nl), body = out.slice(nl + 1);
        if (kind === "text" && body.trim() === "")
            return;
        if (kind === "text" && items[0]?.kind === "text" && items[0].text === body)
            return;                               // the same thing again (copied back from here)
        const entry = kind === "image" ? { kind, path: body, time: Date.now() } : { kind, text: body, time: Date.now() };
        let next = [entry, ...items.filter(i => !(kind === "text" && i.kind === "text" && i.text === body))];
        for (const old of next.slice(max))
            if (old.kind === "image")
                Quickshell.execDetached(["rm", "-f", old.path]);
        items = next.slice(0, max);
        save();
    }

    // put an entry back on the clipboard
    function use(entry) {
        if (entry.kind === "image")
            Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", entry.path]);
        else
            Quickshell.execDetached(["wl-copy", "--", entry.text]);
        open = false;
    }

    function remove(entry) {
        items = items.filter(i => i !== entry);
        if (entry.kind === "image")
            Quickshell.execDetached(["rm", "-f", entry.path]);
        save();
    }

    function clear() {
        items = [];
        Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.png', "sh", dir]);
        save();
    }

    // kept across shell restarts, but only in $XDG_RUNTIME_DIR
    FileView {
        id: file
        path: root.dir + "/history.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d))
                    root.items = d;
            } catch (e) {}
        }
    }
    function save() {
        saveLater.restart();
    }
    Timer {
        id: saveLater
        interval: 500
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", root.dir]);
            file.setText(JSON.stringify(root.items));
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            root.open = !root.open;
        }
    }
}

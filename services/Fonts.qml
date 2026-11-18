pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fonts you've added yourself (settings → look → font → add a font): config/rice/font-add installs them into
// ~/.local/share/fonts/ekitai-user (from a font file, a .zip, or a macOS .dmg / .pkg), and this loads every
// font in that folder into the shell straight away, without a restart. Adding one switches to it.
//   qs -c ekitai ipc call fonts add <file>       (no file: a picker)
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/fonts/ekitai-user"
    property var files: []
    // the families loaded so far, in the order their files came
    readonly property var families: {
        const out = [];
        for (let i = 0; i < loaders.count; i++) {
            const l = loaders.objectAt(i);
            if (l && l.status === FontLoader.Ready && l.name && !out.includes(l.name))
                out.push(l.name);
        }
        return out;
    }
    property bool busy: false
    property string error: ""
    property string pending: ""                  // just added: switch to it once it's loaded

    function add(path) {
        if (busy)
            return;
        busy = true;
        error = "";
        adder.command = [Quickshell.env("HOME") + "/.config/rice/font-add"].concat(path ? [path] : []);
        adder.running = true;
    }

    function rescan() {
        lister.running = true;
    }
    Component.onCompleted: rescan()

    onFamiliesChanged: {
        if (pending && families.includes(pending)) {
            Settings.set("font", pending);
            pending = "";
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", "ls -1 \"$0\" 2>/dev/null", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(f => /\.(ttf|otf|ttc|otc|woff2?)$/i.test(f))
        }
    }

    Process {
        id: adder
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {
                    root.error = "couldn't add it";
                    return;
                }
                if (r.error) {
                    root.error = r.error;
                    return;
                }
                if (r.families?.length) {
                    root.pending = r.families[0];
                    root.rescan();
                    root.familiesChanged();      // (already loaded, from an earlier add)
                }
            }
        }
    }

    Instantiator {
        id: loaders
        model: root.files
        delegate: FontLoader {
            required property string modelData
            source: "file://" + root.dir + "/" + modelData
        }
    }

    IpcHandler {
        target: "fonts"
        function add(path: string): void {
            root.add(path);
        }
        function list(): string {
            return root.families.join("\n");
        }
    }
}

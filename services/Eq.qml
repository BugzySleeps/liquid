pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The equaliser (~/.config/rice/eq does the PipeWire side): 10 bands on every stream that's playing.
// Settings live in ~/.local/state/rice/eq.json, so the panel, the eq command and this stay in sync.
// While it's on, streams that start later get it too.
Singleton {
    id: root

    readonly property var freqs: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var presets: ["flat", "bass", "treble", "vocal", "pop", "rock", "jazz", "classical"]
    readonly property string cmd: Quickshell.env("HOME") + "/.config/rice/eq"

    property bool on: false
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "flat"

    function label(f) {
        return f >= 1000 ? (f / 1000) + "k" : String(f);
    }

    function toggle() {
        on = !on;
        Quickshell.execDetached([cmd, on ? "on" : "off"]);
    }

    // picking a preset means you want to hear it: it turns the EQ on too (one after the other, as they
    // both write eq.json)
    function usePreset(name) {
        preset = name;
        if (on) {
            Quickshell.execDetached([cmd, "preset", name]);
        } else {
            on = true;
            Quickshell.execDetached(["sh", "-c", "\"$0\" preset \"$1\" && \"$0\" on", cmd, name]);
        }
    }

    // a slider moving: the panel follows at once, PipeWire a moment later (so a drag isn't 60 commands)
    function setBand(i, db) {
        const g = gains.slice();
        g[i] = Math.round(Math.max(-12, Math.min(12, db)) * 2) / 2;
        if (g[i] === gains[i])
            return;
        gains = g;
        preset = "custom";
        push.restart();
    }

    Timer {
        id: push
        interval: 70
        onTriggered: Quickshell.execDetached([root.cmd, "set", ...root.gains.map(String)])
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/eq.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.on = !!d.on;
                if (!push.running && Array.isArray(d.gains) && d.gains.length === 10)
                    root.gains = d.gains;
                root.preset = d.preset ?? "custom";
            } catch (e) {}
        }
    }

    // streams that start while it's on get it too: the ones playing audio out (not recordings, like cava's)
    // (kept as the node objects, not their ids: PipeWire hands a new stream an old id, e.g. cmus reopening
    // its output, and by id that looked like a stream that already had it)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)
    property var attached: []
    onStreamsChanged: if (on)
        attachNew()
    onOnChanged: if (on)
        attachNew()

    function attachNew() {
        for (const n of streams)
            if (!attached.includes(n))
                Quickshell.execDetached([cmd, "attach", String(n.id)]);
        attached = streams.slice();
    }
}

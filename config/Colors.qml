pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette, read live from ~/.local/state/rice/palette.json (`rice` writes it on every switch).
// A new palette crossfades in over the old one, so switching never reloads the shell. When the wallpaper
// changes too, the fade waits for it (Wallpaper.qml calls go() as its wipe starts), so both move together.
Singleton {
    id: root

    readonly property color bg: mix("bg")
    readonly property color bg1: mix("bg1")
    readonly property color bg2: mix("bg2")
    readonly property color bg3: mix("bg3")
    readonly property color accent: mix("accent")    // the one colour
    readonly property color mid: mix("mid")          // the same colour, quieter
    readonly property color dim: mix("dim")          // the same colour, barely there
    readonly property color faint: mix("faint")
    readonly property color bright: mix("bright")
    readonly property color alert: mix("alert")

    // the bar and panels sit on near-opaque black so the wallpaper never fights the text; with the glass
    // look (Look.glass) they're see-through instead, a touch of the accent in the tint, frosted by hyprland
    property bool glassy: false
    readonly property color glass: glassy ? Qt.alpha(Qt.tint(bg, Qt.alpha(accent, 0.07)), 0.48) : Qt.alpha(Qt.tint(bg, Qt.alpha(accent, 0.035)), 0.97)

    readonly property string wallpaper: data.wallpaper ?? ""
    readonly property string theme: data.name ?? ""

    // ── reading + crossfading ──────────────────────────────
    readonly property var keys: ["bg", "bg1", "bg2", "bg3", "accent", "mid", "dim", "faint", "bright", "alert"]
    // ekitai green, until the file has been read
    readonly property var fallback: ({ bg: "#000000", bg1: "#030803", bg2: "#071209", bg3: "#0d1c10", accent: "#5fe878", mid: "#2f9e45", dim: "#1f5c2b", faint: "#173d20", bright: "#b8f7c4", alert: "#d4ff6a" })

    property var data: ({})
    property var from: fallback
    property var to: fallback
    property real k: 1

    function mix(key) {
        return Qt.tint(from[key], Qt.alpha(to[key], k));
    }

    function read(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;                                  // half-written: the next change event has the rest
        }
        const c = d.colors ?? {};
        const next = {
            bg: c.bg0, bg1: c.bg1, bg2: c.bg2, bg3: c.bg3, accent: c.accent, mid: c.accent2, dim: c.dim,
            faint: d.hypr?.border_inactive, bright: c.bright, alert: d.term?.color1
        };
        for (const key of keys)
            next[key] = next[key] ?? fallback[key];
        if (keys.every(key => next[key] === to[key])) {
            data = d;
            return;
        }
        if (!loaded) {                               // first read: no fade
            from = next;
            to = next;
        } else if (d.wallpaper && d.wallpaper !== data.wallpaper) {
            pending = next;                          // wait for the new wallpaper to start wiping in
            hold.restart();
        } else {
            begin(next);
        }
        data = d;
    }

    property var pending: null

    function begin(next) {
        const now = {};
        for (const key of keys)
            now[key] = root[key];
        from = now;
        to = next;
        k = 0;
        fade.restart();
    }

    function go() {
        if (!pending)
            return;
        hold.stop();
        begin(pending);
        pending = null;
    }

    Timer {
        id: hold                                     // in case no wallpaper ever calls go()
        interval: 2500
        onTriggered: root.go()
    }

    readonly property int duration: 1000             // the crossfade, and the wallpaper wipe with it

    property bool loaded: false

    NumberAnimation {
        id: fade
        target: root
        property: "k"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.InOutCubic
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/rice/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.read(text());
            root.loaded = true;
        }
    }
}

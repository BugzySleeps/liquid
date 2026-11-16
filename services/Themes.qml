pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Each wallpaper remembers its own look: the shape (square / round / squiggle), liquid glass (on, and its style), and its own set
// of desktop widgets (which ones, where, how big, their shapes and settings). Switching wallpapers keeps the
// one you're leaving and brings back the one you're going to (widgets glide there, or come and go); a
// wallpaper you've never used starts from what's on screen. The lock screen's widgets stay shared.
// Off (Settings.perWall): one look for every wallpaper.
// Saved to ~/.local/state/ekitai/themes.json, keyed by the wallpaper's path.
//   qs -c ekitai ipc call themes list            the wallpapers with a look saved
//   qs -c ekitai ipc call themes reset           forget them all (every wallpaper takes what's on screen)
Singleton {
    id: root

    property var profiles: ({})
    property string current: ""                  // the wallpaper whose look is on screen
    property bool loaded: false
    readonly property bool ready: loaded && Look.loaded && Widgets.restored && Colors.loaded

    onReadyChanged: follow()
    Connections {
        target: Colors
        function onWallpaperChanged() {
            root.follow();
        }
    }

    function snapshot() {
        return { look: Look.shape, glass: Look.glass, glassLook: Look.glassLook(), desktop: Widgets.desktop() };
    }

    function follow() {
        const wall = Colors.wallpaper;
        if (!ready || !wall || wall === current)
            return;
        if (current && Settings.perWall) {
            profiles[current] = snapshot();
            if (profiles[wall])
                apply(profiles[wall]);
        }
        current = wall;
        save();
    }

    function apply(p) {
        Look.set(p.look);
        if (typeof p.glass === "boolean")
            Look.setGlass(p.glass);
        if (p.glassLook)
            Look.setGlassLook(p.glassLook);
        if (Array.isArray(p.desktop)) {
            Widgets.setDesktop(p.desktop);
        } else if (p.widgets) {                  // saved before the sets: just the spots, sizes and shapes
            Widgets.glide();
            for (const w of Widgets.items) {
                const s = p.widgets[w.uid];
                if (!s)
                    continue;
                w.x = s.x;
                w.y = s.y;
                w.w = s.w;
                w.h = s.h;
                w.props = Object.assign({}, w.props, { shape: s.shape, spin: s.spin });
            }
            Widgets.save();
        }
    }

    function save() {
        file.setText(JSON.stringify({ current, profiles }) + "\n");
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/ekitai/themes.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.profiles = d.profiles ?? {};
                root.current = d.current ?? "";
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "themes"
        function reset(): void {
            root.profiles = {};
            root.save();
        }
        function list(): string {
            return Object.keys(root.profiles).map(k => k + "  " + root.profiles[k].look).join("\n");
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// The shape of everything: "square" (hard corners), "round" (rounded boxes, pills, circles) or
// "squiggle" (wavy-edged boxes, scalloped buttons and art, wavy meters). Windows follow too
// (Hyprland rounding). Plus `glass`: liquid-glass surfaces, the blurred wallpaper seen through them, bent at the
// rim, with light on the edge (components/GlassFill.qml, services/Glass.qml; drawn by the shell, no compositor blur). Saved to ~/.local/state/ekitai/look.json.
//   qs -c ekitai ipc call look set round      square | round | squiggle
//   qs -c ekitai ipc call look next
//   qs -c ekitai ipc call look glass on       on | off | toggle
Singleton {
    id: root

    readonly property var shapes: ["square", "round", "squiggle"]
    property string shape: "square"
    property bool glass: false
    // Colors.glass reads this (bound, so the two never drift apart, even across reloads)
    Binding {
        target: Colors
        property: "glassy"
        value: root.glass
    }

    readonly property bool round: shape !== "square"
    readonly property bool wavy: shape === "squiggle"
    readonly property int radius: round ? 14 : 0          // boxes: panels, islands, widgets, cards

    // a radius that never goes past a pill
    function r(w, h) {
        return round ? Math.min(radius, w / 2, h / 2) : 0;
    }

    function set(name) {
        if (!shapes.includes(name) || name === shape)
            return;
        shape = name;
        save();
    }

    function setGlass(on) {
        if (on === glass)
            return;
        glass = on;
        save();
        applyWindows();
    }

    function save() {
        file.setText(JSON.stringify({ shape, glass }) + "\n");
    }

    // Hyprland windows: rounded corners in round / squiggle. Reapplied after a config reload
    // (rice switches reload hyprland, which resets rounding to the theme's).
    onShapeChanged: applyWindows()
    // no compositor blur, even for glass: the shell draws its own (GlassFill), so it costs nothing per frame
    function applyWindows() {
        if (loaded)
            // from `shape` itself: in onShapeChanged, round/wavy/windowRadius may not have updated yet
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { rounding = ${shape === "square" ? 0 : 12}, rounding_power = ${shape === "squiggle" ? 3 : 2}, blur = { enabled = false } } })`]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "configreloaded")
                root.applyWindows();
        }
    }

    // ── saving ─────────────────────────────────────────────
    property bool loaded: false

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/ekitai/look.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (root.shapes.includes(d.shape))
                    root.shape = d.shape;
                if (typeof d.glass === "boolean")
                    root.glass = d.glass;
            } catch (e) {}
            root.loaded = true;
            root.applyWindows();
        }
        onLoadFailed: {                          // first run: the defaults, applied
            root.loaded = true;
            root.applyWindows();
        }
    }

    IpcHandler {
        target: "look"
        function set(name: string): void {
            root.set(name);
        }
        function next(): void {
            root.set(root.shapes[(root.shapes.indexOf(root.shape) + 1) % root.shapes.length]);
        }
        function get(): string {
            return root.shape + (root.glass ? " glass" : "");
        }
        function glass(on: string): void {
            root.setGlass(on === "toggle" ? !root.glass : on === "on");
        }
    }
}

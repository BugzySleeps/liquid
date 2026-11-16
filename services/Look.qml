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
//   qs -c ekitai ipc call look glassStyle clear   clear | tinted | liquid (the glass's tune, see `styles`)
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

    // how the glass looks: a style (clear and tinted like macOS's, liquid the shell's own deep-tinted one), or
    // your own tune of it. frost: how blurred what's behind is · tint: how much colour covers it · bend: how
    // strongly the rim refracts like a lens · shine: light on the rim · hue: the tint from the theme or neutral
    readonly property var styles: ({
            clear: { frost: 0.12, tint: 0.28, bend: 0.85, shine: 0.85, hue: "neutral" },
            tinted: { frost: 0.4, tint: 0.6, bend: 0.7, shine: 0.7, hue: "theme" },
            liquid: { frost: 0.63, tint: 0.54, bend: 0.45, shine: 0.55, hue: "theme" }
        })
    property string glassStyle: "clear"
    property var tune: styles.clear
    readonly property var glassKeys: ["frost", "tint", "bend", "shine"]

    function setGlassStyle(name) {
        if (!styles[name])
            return;
        glassStyle = name;
        tune = Object.assign({}, styles[name]);
        save();
    }
    // one knob moved: it's your own tune now
    function setTune(key, v) {
        const t = Object.assign({}, tune);
        t[key] = key === "hue" ? v : Math.max(0, Math.min(1, v));
        tune = t;
        glassStyle = "custom";
        saveSoon.restart();
    }
    // all of it at once (a wallpaper's theme)
    function setGlassLook(g) {
        if (!g)
            return;
        glassStyle = g.style ?? "custom";
        tune = fixTune(g.tune) ?? (styles[glassStyle] ? Object.assign({}, styles[glassStyle]) : tune);
        save();
    }
    function glassLook() {
        return { style: glassStyle, tune: Object.assign({}, tune) };
    }
    function fixTune(t) {
        if (!t || typeof t !== "object")
            return null;
        const o = Object.assign({}, styles.clear);
        for (const k of glassKeys)
            if (typeof t[k] === "number")
                o[k] = Math.max(0, Math.min(1, t[k]));
        if (t.hue === "theme" || t.hue === "neutral")
            o.hue = t.hue;
        return o;
    }
    Timer {
        id: saveSoon
        interval: 400
        onTriggered: root.save()
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
        file.setText(JSON.stringify({ shape, glass, glassStyle, tune }) + "\n");
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
                if (typeof d.glassStyle === "string")
                    root.glassStyle = d.glassStyle;
                root.tune = root.fixTune(d.tune) ?? Object.assign({}, root.styles[root.glassStyle] ?? root.styles.clear);
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
        function glassStyle(name: string): void {
            root.setGlassStyle(name);
        }
    }
}

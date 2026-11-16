pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Night light: warms the screen through a Hyprland screen shader (decoration.screen_shader), so it needs
// nothing installed. Screenshots and recordings keep their true colours. Settings.nightMode is "off", "on" or
// "auto" (from Settings.nightFrom to Settings.nightTo o'clock, easing in over the first 20 minutes);
// Settings.nightTemp is how warm, in kelvin.
//   qs -c ekitai ipc call night toggle
//   qs -c ekitai ipc call night set off|on|auto
Singleton {
    id: root

    property date now: new Date()
    Timer {
        running: Settings.nightMode === "auto"
        interval: 30000
        repeat: true
        onTriggered: root.now = new Date()
    }

    // how far into the night it is, 0 … 1 (auto: easing in over 20 minutes)
    readonly property real depth: {
        if (Settings.nightMode === "on")
            return 1;
        if (Settings.nightMode !== "auto")
            return 0;
        const m = now.getHours() * 60 + now.getMinutes();
        const from = Settings.nightFrom * 60, to = Settings.nightTo * 60;
        const into = (m - from + 1440) % 1440;           // minutes since it began
        const span = (to - from + 1440) % 1440;
        return into < span ? Math.min(1, (into + 1) / 20) : 0;
    }
    readonly property bool active: depth > 0
    readonly property int target: Math.round(6500 - (6500 - Settings.nightTemp) * depth)

    // switching by hand glides there over a second and a half instead of jumping
    property real kelvin: 6500
    Behavior on kelvin {
        NumberAnimation {
            duration: 1500
            easing.type: Easing.InOutSine
        }
    }
    Component.onCompleted: kelvin = target
    onTargetChanged: kelvin = target

    // the shown temperature in 50 K steps: a new shader each step
    readonly property int step: Math.round(kelvin / 50) * 50
    onStepChanged: apply.restart()
    Timer {
        id: apply
        interval: 16
        onTriggered: root.write()
    }

    // a colour temperature as an RGB multiplier, relative to daylight (6500 K = no change)
    function rgb(k) {
        const t = k / 100, c = v => Math.max(0, Math.min(1, v / 255));
        return [t <= 66 ? 1 : c(329.698727446 * Math.pow(t - 60, -0.1332047592)),
            t <= 66 ? c(99.4708025861 * Math.log(t) - 161.1195681661) : c(288.1221695283 * Math.pow(t - 60, -0.0755148492)),
            t >= 66 ? 1 : t <= 19 ? 0 : c(138.5177312231 * Math.log(t - 10) - 305.0447927307)];
    }

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/ekitai"
    property int flip: 0                         // two files in turn, so Hyprland sees a new path each time
    function write() {
        if (step >= 6500) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { screen_shader = '' } })"]);
            return;
        }
        const d = rgb(6500), w = rgb(step);
        const m = [0, 1, 2].map(i => (w[i] / d[i]).toFixed(4)).join(", ");
        flip = 1 - flip;
        const path = dir + "/night-" + flip + ".frag";
        const src = "#version 300 es\nprecision highp float;\nin vec2 v_texcoord;\nuniform sampler2D tex;\nout vec4 fragColor;\n"
            + "void main() {\n    vec4 c = texture(tex, v_texcoord);\n    fragColor = vec4(c.rgb * vec3(" + m + "), c.a);\n}\n";
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1" && hyprctl eval "hl.config({ decoration = { screen_shader = \'$1\' } })" >/dev/null',
            "sh", path, src]);
    }

    // reloading Hyprland's config clears the shader: put it back
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "configreloaded" && root.step < 6500)
                apply.restart();
        }
    }

    function toggle() {
        Settings.set("nightMode", active ? "off" : "on");
    }

    IpcHandler {
        target: "night"
        function toggle(): void {
            root.toggle();
        }
        function set(mode: string): void {
            if (["off", "on", "auto"].includes(mode))
                Settings.set("nightMode", mode);
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Little sounds (off unless Settings.sounds): bubbles when unlocking, a click for screenshots, a tick for
// volume and brightness. Two more have their own switches and styles, both on by default:
//   notifications (Settings.notifSounds / notifStyle): a style's opening sound, or the drip (notify())
//   terminals (Settings.termSounds / termStyle): term-<style>-open as one opens, -close as one closes
//   the lock screen (Settings.lockSounds): its liquid's water sounds, timed to its animations (lock())
// Made by sounds/make.py (term-mine-* are your own clips, from ~/sounds); played with paplay.
Singleton {
    id: root

    property real lastTick: 0

    function play(name) {
        if (!Settings.sounds)
            return;
        if (name === "tick") {                   // holding a key: not a tick every repeat
            const now = Date.now();
            if (now - lastTick < 90)
                return;
            lastTick = now;
        }
        out(name, name === "tick" ? 0.6 : 1);
    }

    // a notification (Notifs calls this): its own switch and style; a burst of them makes one sound
    property real lastNotify: 0
    function notify() {
        if (!Settings.notifSounds)
            return;
        const now = Date.now();
        if (now - lastNotify < 600)
            return;
        lastNotify = now;
        out(notifSound(Settings.notifStyle), 1);
    }
    function notifSound(style) {
        return style === "drip" ? "drip" : "term-" + style + "-open";
    }

    // the lock screen's liquid (LockView calls this as each animation starts): fill, intro, drain, splash, and a
    // drop / undrop per key. Every screen has its own LockView, so the same sound at once plays once.
    readonly property var lockGain: ({ drop: 0.45, undrop: 0.35 })
    property var lastLock: ({})
    function lock(kind) {
        if (!Settings.lockSounds)
            return;
        const now = Date.now();
        if (now - (lastLock[kind] ?? 0) < 40)
            return;
        lastLock[kind] = now;
        out("lock-" + (kind === "drop" ? "drop-" + (1 + Math.floor(Math.random() * 4)) : kind), lockGain[kind] ?? 0.85);
    }

    // a terminal style's open, then its close: for trying them out
    function preview(style) {
        out("term-" + style + "-open", 1);
        previewClose.style = style;
        previewClose.interval = style === "mine" ? 900 : 650;   // after the open has finished
        previewClose.restart();
    }
    Timer {
        id: previewClose
        property string style
        onTriggered: root.out("term-" + style + "-close", 1)
    }

    function out(name, gain) {
        const vol = Math.round(65536 * Math.max(0, Math.min(1, Settings.soundVolume)) * gain);
        // to the output the sound's actually going to (where the music plays, else the default), like the volume keys
        const dev = Audio.sink?.name ?? "";
        Quickshell.execDetached(["paplay", "--volume=" + vol, ...(dev ? ["--device=" + dev] : []), Quickshell.shellPath("sounds/" + name + ".wav")]);
    }

    Connections {
        target: Lock
        function onLeave() {
            if (!Settings.lockSounds)            // else the lock's own drain sound
                root.play("bubble");
        }
    }

    // ── terminals ──
    // closewindow only says which address went, so remember which open windows are terminals
    readonly property var terminals: ["kitty", "alacritty", "foot", "footclient", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "xterm", "konsole", "gnome-terminal-server"]
    property var open: ({})                      // address (no 0x) → true, for the terminals

    function isTerminal(cls) {
        return terminals.includes(String(cls).toLowerCase());
    }

    // the terminals already open when the shell starts
    Process {
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = {};
                    for (const c of JSON.parse(text))
                        if (root.isTerminal(c.class))
                            o[c.address.replace(/^0x/, "")] = true;
                    root.open = o;
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "openwindow") {       // address,workspace,class,title
                const [addr, , cls] = e.data.split(",");
                if (!root.isTerminal(cls))
                    return;
                root.open[addr] = true;
                if (Settings.termSounds)
                    root.out("term-" + Settings.termStyle + "-open", 1);
            } else if (e.name === "closewindow") {   // address
                const addr = e.data.trim();
                if (!root.open[addr])
                    return;
                delete root.open[addr];
                if (Settings.termSounds)
                    root.out("term-" + Settings.termStyle + "-close", 1);
            }
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The settings app's own options (the rest live where they always did: Look, Widgets, Eq, wallpapers),
// saved to ~/.local/state/ekitai/settings.json. The app itself is settings/SettingsApp.qml (SUPER+I).
//   qs -c ekitai ipc call settings toggle
//   qs -c ekitai ipc call settings set artAccent true
//   qs -c ekitai ipc call settings open look|wallpaper|bar|widgets|lock|sound|notifications|about
Singleton {
    id: root

    property bool open: false
    property string page: "look"

    // what the bar shows
    property bool barTitle: false                // the focused window's name
    property bool barMedia: true                 // the song
    property bool barMeters: false               // cpu / ram
    property string barStyle: "strip"            // "strip": one borderless bar · "islands": three outlined boxes

    // while music plays, the shell and window borders take their colours from the album art
    property bool artAccent: false
    // ...and (only with artAccent on) the wallpaper turns into one made from the cover's colours, with the cover and the song on it
    property bool artWall: false
    // wallpapers made alive with ~/.config/rice/livewall move (the sea rolls, what floats on it bobs)
    property bool liveWall: true
    // a scene wallpaper's colour, by scene name ({ claude: "#5b8cff" }); none: its own. Album colours win while music plays.
    property var sceneTints: ({})
    property bool ledPulse: true                 // LED strips (~/.config/rice/leds) throb with the music
    function tintScene(name, hex) {
        const t = Object.assign({}, sceneTints);
        if (hex)
            t[name] = hex;
        else
            delete t[name];
        set("sceneTints", t);
    }
    // its design (shaders/artwall.frag): "waves", "aurora", "drips", "orb", or "shuffle" (one per album)
    property string artWallStyle: "waves"

    // the shell's font (settings → look → font): any installed family; Style.font follows it
    property string font: "Departure Mono"
    Binding {
        target: Style
        property: "font"
        value: root.font
    }

    // each wallpaper keeps its own shape and widget layout (Themes)
    property bool perWall: true

    // the desktop widgets as the row of windows scrolls (Drift): "parallax" (drift behind, slower), "canvas"
    // (scroll with the windows) or "pinned" (stay put)
    property string canvasWidgets: "parallax"

    // the desktop widgets float at depths over the wallpaper: they lean from the pointer, cast shadows, and
    // sink back while windows are open (Drift)
    property bool depth: true

    // music, lyrics and visualizer widgets hide while nothing's playing (off: they always show)
    property bool hideIdleMusic: false

    // the dynamic island (bar/DynamicIsland.qml)
    property string osdStyle: "island"           // volume / brightness: "island", or "vial" (the side indicator)
    property bool islandTracks: true             // a new track swells it with the cover
    property bool islandNotifs: true             // simple notifications show in it instead of a popup
    property bool islandClaude: true             // Claude Code finishing, or waiting on you (config/rice/claude-island)

    // music sounds underwater while the lock screen's up
    property bool lockMuffle: true

    // performance mode (Perf): "auto" (fullscreen / battery), "always" or "never"
    property string perf: "auto"

    // little sounds (Sounds): off by default
    property bool sounds: false
    property real soundVolume: 0.5
    // a terminal opening / closing makes its own sound (its own switch, on by default)
    property bool termSounds: true
    property string termStyle: "mine"            // mine (your own clips) | ps2 | glitch | crt | hud (sounds/make.py)
    readonly property var termStyles: ["mine", "ps2", "glitch", "crt", "hud"]
    // a notification makes a sound too (island or popup; not in do-not-disturb): one of the terminal
    // styles' opening sounds, or the old water drip
    property bool notifSounds: true
    property string notifStyle: "ps2"
    readonly property var notifStyles: ["mine", "ps2", "glitch", "crt", "hud", "drip"]
    // the lock screen's liquid makes water sounds as it moves (on by default)
    property bool lockSounds: true

    // the idle tide (Tide): after idleAfter minutes away the liquid rises over the desktop for tideRise
    // seconds, then locks. Touching anything drains it.
    property bool idleTide: true
    property real idleAfter: 5
    readonly property var idleAfters: [2, 5, 10, 15, 30]
    property int tideRise: 60
    readonly property var tideRises: [30, 60, 120]

    // night light (Night): off · on · auto (from nightFrom to nightTo o'clock); how warm, in kelvin
    property string nightMode: "off"
    property int nightTemp: 4000
    property int nightFrom: 20
    property int nightTo: 7

    function set(key, value) {
        root[key] = value;
        saveLater.restart();
    }

    property bool loaded: false
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/ekitai/settings.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                for (const k of ["barTitle", "barMedia", "barMeters", "artAccent", "artWall", "liveWall", "hideIdleMusic", "perWall", "depth", "ledPulse"])
                    if (typeof d[k] === "boolean")
                        root[k] = d[k];
                if (["island", "vial"].includes(d.osdStyle))
                    root.osdStyle = d.osdStyle;
                for (const k of ["islandTracks", "islandNotifs", "islandClaude", "lockMuffle"])
                    if (typeof d[k] === "boolean")
                        root[k] = d[k];
                if (["waves", "aurora", "drips", "orb", "shuffle"].includes(d.artWallStyle))
                    root.artWallStyle = d.artWallStyle;
                if (typeof d.font === "string" && d.font)   // (one you added loads a moment later: Fonts)
                    root.font = d.font;
                if (["parallax", "canvas", "pinned"].includes(d.canvasWidgets))
                    root.canvasWidgets = d.canvasWidgets;
                if (["strip", "islands"].includes(d.barStyle))
                    root.barStyle = d.barStyle;
                if (["auto", "always", "never"].includes(d.perf))
                    root.perf = d.perf;
                if (typeof d.sounds === "boolean")
                    root.sounds = d.sounds;
                if (typeof d.termSounds === "boolean")
                    root.termSounds = d.termSounds;
                if (root.termStyles.includes(d.termStyle))
                    root.termStyle = d.termStyle;
                if (typeof d.lockSounds === "boolean")
                    root.lockSounds = d.lockSounds;
                if (typeof d.idleTide === "boolean")
                    root.idleTide = d.idleTide;
                if (root.idleAfters.includes(d.idleAfter))
                    root.idleAfter = d.idleAfter;
                if (root.tideRises.includes(d.tideRise))
                    root.tideRise = d.tideRise;
                if (["off", "on", "auto"].includes(d.nightMode))
                    root.nightMode = d.nightMode;
                for (const k of ["nightTemp", "nightFrom", "nightTo"])
                    if (typeof d[k] === "number")
                        root[k] = d[k];
                if (typeof d.notifSounds === "boolean")
                    root.notifSounds = d.notifSounds;
                if (root.notifStyles.includes(d.notifStyle))
                    root.notifStyle = d.notifStyle;
                if (typeof d.soundVolume === "number")
                    root.soundVolume = d.soundVolume;
                if (d.sceneTints && typeof d.sceneTints === "object")
                    root.sceneTints = d.sceneTints;
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    Timer {
        id: saveLater
        interval: 300
        onTriggered: file.setText(JSON.stringify({ barTitle: root.barTitle, barMedia: root.barMedia, barMeters: root.barMeters, barStyle: root.barStyle, canvasWidgets: root.canvasWidgets, depth: root.depth, font: root.font, artAccent: root.artAccent, artWall: root.artWall, artWallStyle: root.artWallStyle, liveWall: root.liveWall, perWall: root.perWall, hideIdleMusic: root.hideIdleMusic, osdStyle: root.osdStyle, islandTracks: root.islandTracks, islandNotifs: root.islandNotifs, islandClaude: root.islandClaude, lockMuffle: root.lockMuffle, perf: root.perf, sounds: root.sounds, soundVolume: root.soundVolume, termSounds: root.termSounds, termStyle: root.termStyle, notifSounds: root.notifSounds, notifStyle: root.notifStyle, lockSounds: root.lockSounds, idleTide: root.idleTide, idleAfter: root.idleAfter, tideRise: root.tideRise, nightMode: root.nightMode, nightTemp: root.nightTemp, nightFrom: root.nightFrom, nightTo: root.nightTo, sceneTints: root.sceneTints, ledPulse: root.ledPulse }) + "\n")
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            root.open = !root.open;
        }
        function set(key: string, json: string): void {   // settings set artAccent true
            if (!(key in root))
                return;
            try {
                root.set(key, JSON.parse(json));
            } catch (e) {}
        }
        function open(page: string): void {
            if (page)
                root.page = page;
            root.open = true;
        }
    }
}

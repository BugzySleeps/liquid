pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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

    // each wallpaper keeps its own shape and widget layout (Themes)
    property bool perWall: true

    // music, lyrics and visualizer widgets hide while nothing's playing (off: they always show)
    property bool hideIdleMusic: false

    // the dynamic island (bar/DynamicIsland.qml)
    property string osdStyle: "island"           // volume / brightness: "island", or "vial" (the side indicator)
    property bool islandTracks: true             // a new track swells it with the cover
    property bool islandNotifs: true             // simple notifications show in it instead of a popup

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
                for (const k of ["barTitle", "barMedia", "barMeters", "artAccent", "hideIdleMusic", "perWall"])
                    if (typeof d[k] === "boolean")
                        root[k] = d[k];
                if (["island", "vial"].includes(d.osdStyle))
                    root.osdStyle = d.osdStyle;
                for (const k of ["islandTracks", "islandNotifs", "lockMuffle"])
                    if (typeof d[k] === "boolean")
                        root[k] = d[k];
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
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    Timer {
        id: saveLater
        interval: 300
        onTriggered: file.setText(JSON.stringify({ barTitle: root.barTitle, barMedia: root.barMedia, barMeters: root.barMeters, barStyle: root.barStyle, artAccent: root.artAccent, perWall: root.perWall, hideIdleMusic: root.hideIdleMusic, osdStyle: root.osdStyle, islandTracks: root.islandTracks, islandNotifs: root.islandNotifs, lockMuffle: root.lockMuffle, perf: root.perf, sounds: root.sounds, soundVolume: root.soundVolume, termSounds: root.termSounds, termStyle: root.termStyle, notifSounds: root.notifSounds, notifStyle: root.notifStyle, lockSounds: root.lockSounds, idleTide: root.idleTide, idleAfter: root.idleAfter, tideRise: root.tideRise, nightMode: root.nightMode, nightTemp: root.nightTemp, nightFrom: root.nightFrom, nightTo: root.nightTo }) + "\n")
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

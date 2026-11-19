pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The colour the wallpaper is showing, for LED strips (~/.config/rice/leds: a service that keeps them in step):
// the album's while album colours are on and a track plays, else the colour picked for a scene wallpaper
// (Settings.sceneTints), else the theme's accent. Written to ~/.local/state/ekitai/leds.json when it changes,
// with whether music plays and whether to pulse with it.
Singleton {
    id: root

    readonly property color colour: Media.accentFrom ? Colors.accent : Media.homeSceneName && Settings.sceneTints[Media.homeSceneName] ? Settings.sceneTints[Media.homeSceneName] : Colors.accent
    readonly property string hex: "#" + [colour.r, colour.g, colour.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("")

    // pulse: the strip throbs with the music's bass while a track plays (Settings.ledPulse; the service listens itself)
    readonly property string state: JSON.stringify({ colour: hex, playing: Media.playing, pulse: Settings.ledPulse })
    onStateChanged: later.restart()
    Component.onCompleted: later.restart()
    Timer {
        id: later
        interval: 150                                // the colour settles (a crossfade's first frames) before it's sent
        onTriggered: file.setText(root.state + "\n")
    }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/ekitai/leds.json"
        printErrors: false
    }
}

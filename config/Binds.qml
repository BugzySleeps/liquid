pragma Singleton

import QtQuick
import Quickshell

// The keys worth knowing, for the cheat sheets (settings → about, and the welcome). The binds themselves
// are in ~/.config/hypr/hyprland.lua.
Singleton {
    readonly property var list: [
        ["SUPER R", "launcher"], ["SUPER T", "wallpaper picker"], ["SUPER N", "control centre"], ["SUPER I", "settings"],
        ["SUPER W", "edit widgets"], ["SUPER ESC", "lock"], ["SUPER SHIFT V", "clipboard"], ["ALT TAB", "switch windows"],
        ["SUPER O", "all workspaces"], ["SUPER .", "emoji"], ["PRINT", "screenshot (editor)"], ["SHIFT PRINT", "full screenshot"],
        ["SUPER TAB", "hide the bar"], ["SUPER SHIFT M", "cmus"]
    ]
}

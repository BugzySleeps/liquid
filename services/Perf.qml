pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Performance mode: the shell eases off when it should. cava and every visualizer stop, and the glass
// look's blur switches off. Settings.perf picks when: "auto" (a fullscreen window on the focused
// workspace, or running on battery), "always", or "never".
Singleton {
    id: root

    readonly property bool fullscreen: Hyprland.focusedWorkspace?.hasFullscreen ?? false
    readonly property bool battery: UPower.onBattery
    readonly property bool low: Settings.perf === "always" || (Settings.perf === "auto" && (fullscreen || battery))
    readonly property string why: Settings.perf === "always" ? "always on" : fullscreen ? "a window is fullscreen" : battery ? "on battery" : ""

    // blur is Hyprland's: Look puts it back to the glass setting when this ends
    onLowChanged: Look.applyWindows()
}

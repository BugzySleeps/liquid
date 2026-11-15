pragma Singleton

import QtQuick
import Quickshell

// Sizes, fonts and timings. Colours live in Colors.qml (from the theme).
// Text is Departure Mono, a pixel font drawn on an 11px grid: it's only crisp at 11, 22, 33… px, so every
// text size goes through px(). It has no bold either: emphasis is brightness. Icons are Symbols Nerd Font
// (outlines, any size). Both ship in ~/dotfiles/fonts.
Singleton {
    readonly property string font: "Departure Mono"
    readonly property string icons: "Symbols Nerd Font Mono"
    readonly property string cjk: "Noto Sans CJK JP"

    readonly property int text: 11
    readonly property int small: 11
    readonly property int big: 22
    readonly property int icon: 14

    // the nearest size the pixel font is crisp at
    function px(n) {
        return Math.max(11, Math.round(n / 11) * 11);
    }

    readonly property int barHeight: 30
    readonly property int gap: 6        // space around the bar and between bar and panels
    readonly property int edge: 8       // distance from the screen sides
    readonly property int pad: 14       // inside panels
    readonly property int line: 1       // every border is a hairline

    readonly property int fast: 120
    readonly property int med: 240
    readonly property int slow: 420
}

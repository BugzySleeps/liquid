import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Settings (SUPER+I): everything that's otherwise spread over menus, in one place.
//   look · wallpaper · bar · widgets · lock screen · sound · notifications · about (and the keys)
PanelWindow {
    id: win

    readonly property bool open: Settings.open
    // built only while open (shell.qml, Lazy): it starts closed and follows `open`, so it fades in all the same
    property real t: 0
    Component.onCompleted: {
        t = Qt.binding(() => open ? 1 : 0);
        if (open)
            openChanged();
    }
    Behavior on t {
        NumberAnimation {
            duration: win.open ? Style.med : Style.fast
            easing.type: Easing.OutCubic
        }
    }

    screen: Ui.screen
    visible: t > 0
    color: "transparent"
    implicitWidth: 880
    implicitHeight: 580
    WlrLayershell.namespace: "ekitai-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: if (open) {
        Ui.panel = "";
        walls.running = true;
        keys.forceActiveFocus();
    }

    // a click outside closes it. The grab starts a moment after it opens: opened from a button in another panel
    // (the control centre's gear), the rest of that click lands outside, which would close it straight away.
    HyprlandFocusGrab {
        active: win.open && grabDelay.done
        windows: [win]
        onCleared: Settings.open = false
    }
    Timer {
        id: grabDelay
        property bool done: false
        interval: 250
        running: win.open
        onRunningChanged: if (running)
            done = false
        onTriggered: done = true
    }

    // the wallpapers on offer (the picker's list)
    property var wallList: []
    Process {
        id: walls
        command: ["sh", "-c", "~/.config/rice/rice walls --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.wallList = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    readonly property var pages: [
        ["look", "󰏘", "look"], ["wallpaper", "󰸉", "wallpaper"], ["bar", "󰍜", "bar"], ["widgets", "󰕮", "widgets"],
        ["lock", "󰌾", "lock screen"], ["sound", "󰕾", "sound"], ["notifications", "󰂚", "notifications"], ["about", "󰋽", "about"]
    ]

    Frame {
        id: frame
        anchors.fill: parent
        anchors.margins: 2
        scale: 0.97 + 0.03 * win.t
        opacity: win.t
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Settings.open = false
            Keys.onUpPressed: win.move(-1)
            Keys.onDownPressed: win.move(1)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 18

            // ── the rail ──
            ColumnLayout {
                // its tabs fill its width, which a layout would pass up as "fill the window": pin it
                Layout.preferredWidth: 180
                Layout.maximumWidth: 180
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: 4

                RowLayout {
                    Layout.bottomMargin: 12
                    spacing: 10
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Look.round ? 17 : 0
                        color: Colors.accent
                        Logo {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            color: Colors.bg
                        }
                    }
                    Column {
                        Txt {
                            text: "settings"
                            font.bold: true
                            font.pixelSize: Style.px(Style.big)
                            color: Colors.bright
                        }
                        Txt {
                            text: "ekitai"
                            font.pixelSize: Style.small
                            color: Colors.mid
                        }
                    }
                }

                Repeater {
                    model: win.pages
                    Frame {
                        id: tab
                        required property var modelData
                        readonly property bool on: Settings.page === modelData[0]
                        Layout.fillWidth: true
                        implicitHeight: 34
                        pill: true
                        color: on ? Colors.accent : tabArea.containsMouse ? Colors.bg2 : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 10
                            Icon {
                                text: tab.modelData[1]
                                color: tab.on ? Colors.bg : Colors.accent
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: tab.modelData[2]
                                font.bold: tab.on
                                color: tab.on ? Colors.bg : Colors.bright
                            }
                        }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.page = tab.modelData[0]
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                Txt {
                    text: "esc to close"
                    font.pixelSize: Style.small
                    color: Colors.dim
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Colors.faint
            }

            // ── the page ──
            Flickable {
                id: pageFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: pageCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: pageCol
                    width: pageFlick.width
                    spacing: 18

                    Txt {
                        text: (win.pages.find(p => p[0] === Settings.page) ?? ["", "", ""])[2]
                        font.pixelSize: Style.px(20)
                        font.bold: true
                        color: Colors.bright
                    }

                    // ─ look ─
                    Column {
                        visible: Settings.page === "look"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "shape"
                            hint: "square corners, rounded, or wavy edges and scalloped buttons. windows follow."
                            Repeater {
                                model: [["󰝤", "square"], ["󰄰", "round"], ["󰏰", "squiggle"]]
                                Chip {
                                    required property var modelData
                                    text: modelData[0] + " " + modelData[1]
                                    on: Look.shape === modelData[1]
                                    onClicked: Look.set(modelData[1])
                                }
                            }
                        }
                        // the font: too many choices for an Option's row, so they wrap underneath
                        Column {
                            id: fontOpt
                            width: parent.width
                            spacing: 6
                            // a few that suit it (the ones installed), the ones you've added, and the one in use, each
                            // written in itself
                            readonly property var picks: {
                                const out = ["Departure Mono", "VCR OSD Mono", "JetBrains Mono", "Iosevka", "Fira Code", "MesloLGS Nerd Font", "DejaVu Sans Mono", "Noto Sans Mono", "Inter", "Noto Sans", "Cantarell"].filter(f => Qt.fontFamilies().includes(f));
                                for (const f of Fonts.families.concat([Settings.font]))
                                    if (!out.includes(f))
                                        out.push(f);
                                return out;
                            }
                            Txt {
                                text: "font  ·  " + Settings.font.toLowerCase()
                                font.bold: true
                                color: Colors.bright
                            }
                            Txt {
                                width: parent.width
                                text: "the shell's text" + (Settings.perWall ? ", kept per wallpaper" : "") + ". departure mono is a pixel font, crisp at fixed sizes; the others draw smooth. add your own (a font file, a .zip, or a mac .dmg / .pkg), or type any installed font's name."
                                wrapMode: Text.WordWrap
                                font.pixelSize: Style.small
                                color: Colors.mid
                            }
                            Txt {
                                visible: Fonts.error !== ""
                                text: "couldn't add that: " + Fonts.error
                                font.pixelSize: Style.small
                                color: Colors.bright
                            }
                            Flow {
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: fontOpt.picks
                                    Chip {
                                        required property string modelData
                                        text: modelData.toLowerCase()
                                        family: modelData
                                        on: Settings.font === modelData
                                        onClicked: Settings.set("font", modelData)
                                    }
                                }
                                Chip {
                                    text: Fonts.busy ? "󰔟 adding…" : "󰐕 add a font"
                                    onClicked: Fonts.add("")
                                }
                                Field {
                                    width: 170
                                    height: 22
                                    placeholder: "font name or file…"
                                    onSubmitted: t => {
                                        t = t.trim();
                                        if (t.startsWith("/") || t.startsWith("~")) {   // a file: add it
                                            Fonts.add(t);
                                        } else {        // a name: matched without caring about case; only installed ones
                                            const f = Qt.fontFamilies().find(x => x.toLowerCase() === t.toLowerCase());
                                            if (f)
                                                Settings.set("font", f);
                                        }
                                        text = "";
                                    }
                                }
                            }
                        }
                        Option {
                            title: "per wallpaper"
                            hint: "each wallpaper keeps its own shape, liquid glass (and its style) and desktop widgets (which ones, where, how big, their shapes), like its own theme. switch wallpapers and they come back."
                            Chip {
                                text: "off"
                                on: !Settings.perWall
                                onClicked: Settings.set("perWall", false)
                            }
                            Chip {
                                text: "󰸉 on"
                                on: Settings.perWall
                                onClicked: Settings.set("perWall", true)
                            }
                        }
                        Option {
                            title: "performance mode"
                            hint: (Perf.low ? "on now (" + Perf.why + "): " : "") + "cava and the visualizers pause. auto: while a window is fullscreen or on battery."
                            Repeater {
                                model: ["auto", "always", "never"]
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Settings.perf === modelData
                                    onClicked: Settings.set("perf", modelData)
                                }
                            }
                        }
                        Option {
                            title: "colour from album art"
                            hint: "while music plays, the shell and window borders take the cover's colours, track by track."
                            Chip {
                                text: Settings.artAccent ? "󰏘 on" : "off"
                                on: Settings.artAccent
                                onClicked: Settings.set("artAccent", !Settings.artAccent)
                            }
                        }
                        Option {
                            title: "animated wallpaper"
                            hint: "wallpapers brought to life with ~/.config/rice/livewall move: the sea rolls and glitters, and what floats on it bobs. still in performance mode."
                            Chip {
                                text: Settings.liveWall ? "󰔉 on" : "off"
                                on: Settings.liveWall
                                onClicked: Settings.set("liveWall", !Settings.liveWall)
                            }
                        }
                        Option {
                            title: "album wallpaper"
                            hint: "with colour from album art on, the wallpaper is made from the cover's colours too, with the cover and the song on it, and a design that moves with the music: waves, aurora, drips, a glass orb, or shuffle for one per album. still in performance mode."
                            enabled: Settings.artAccent
                            opacity: enabled ? 1 : 0.4
                            Chip {
                                text: Settings.artWall ? "󰸉 on" : "off"
                                on: Settings.artWall
                                onClicked: Settings.set("artWall", !Settings.artWall)
                            }
                            Repeater {
                                model: ["waves", "aurora", "drips", "orb", "shuffle"]
                                Chip {
                                    required property string modelData
                                    visible: Settings.artWall
                                    text: modelData
                                    on: Settings.artWallStyle === modelData
                                    onClicked: Settings.set("artWallStyle", modelData)
                                }
                            }
                        }
                        Option {
                            title: "liquid glass"
                            hint: "the bar, panels and widgets turn to glass: the wallpaper frosted behind them, bent at the rim, light on the edge. drawn by the shell, so it's light on the gpu."
                            Chip {
                                text: "off"
                                on: !Look.glass
                                onClicked: Look.setGlass(false)
                            }
                            Chip {
                                text: "󰂵 on"
                                on: Look.glass
                                onClicked: Look.setGlass(true)
                            }
                        }
                        Option {
                            visible: Look.glass
                            title: "glass style"
                            hint: ({ clear: "like macOS's clear glass: barely tinted, lightly frosted, a thick bent rim catching the light.", tinted: "like macOS's tinted glass: more frosted, the theme's colour over it so text stands out more.", liquid: "the shell's own: deep frost, the theme's colour, a softer rim.", custom: "your own tune, from the knobs below." })[Look.glassStyle] ?? ""
                            Repeater {
                                model: ["clear", "tinted", "liquid"]
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Look.glassStyle === modelData
                                    onClicked: Look.setGlassStyle(modelData)
                                }
                            }
                            Chip {
                                visible: Look.glassStyle === "custom"
                                text: "custom"
                                on: true
                            }
                        }
                        Repeater {
                            model: [["frost", "frost", "how blurred the wallpaper behind is"], ["tint", "tint", "how much colour covers it: less is clearer, more is easier to read on"], ["bend", "refraction", "how strongly the rim bends what's behind it, like a lens"], ["shine", "rim light", "the light catching the edge"]]
                            Option {
                                required property var modelData
                                visible: Look.glass
                                title: modelData[1]
                                hint: modelData[2] + " · " + Math.round(Look.tune[modelData[0]] * 100) + "%"
                                SegSlider {
                                    width: 200
                                    segments: 20
                                    value: Look.tune[modelData[0]]
                                    onMoved: v => Look.setTune(modelData[0], v)
                                }
                            }
                        }
                        Option {
                            visible: Look.glass
                            title: "glass colour"
                            hint: "tinted with the theme's colours, or a neutral smoke like macOS"
                            Chip {
                                text: "theme"
                                on: Look.tune.hue === "theme"
                                onClicked: Look.setTune("hue", "theme")
                            }
                            Chip {
                                text: "neutral"
                                on: Look.tune.hue === "neutral"
                                onClicked: Look.setTune("hue", "neutral")
                            }
                        }
                    }

                    // ─ wallpaper ─
                    Column {
                        visible: Settings.page === "wallpaper"
                        width: parent.width
                        spacing: 12
                        Txt {
                            width: parent.width
                            text: "picking one recolours everything from it. add your own to ~/Pictures/wallpapers."
                            wrapMode: Text.WordWrap
                            font.pixelSize: Style.small
                            color: Colors.mid
                        }
                        Flow {
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: win.wallList
                                Frame {
                                    id: wcard
                                    required property var modelData
                                    width: (pageCol.width - 20) / 3
                                    height: width * 9 / 16 + 34
                                    color: modelData.colors?.bg1 ?? Colors.bg1
                                    border.width: modelData.current ? 2 : Style.line
                                    border.color: modelData.current ? Colors.accent : Colors.faint
                                    clip: true
                                    Image {
                                        x: 3
                                        y: 3
                                        width: parent.width - 6
                                        height: (parent.width - 6) * 9 / 16
                                        source: wcard.modelData.path ? "file://" + wcard.modelData.path : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 360
                                        asynchronous: true
                                    }
                                    Row {
                                        x: 3
                                        y: (parent.width - 6) * 9 / 16 + 3
                                        width: parent.width - 6
                                        Repeater {
                                            model: Object.values(wcard.modelData.colors ?? {})
                                            Rectangle {
                                                required property var modelData
                                                width: (wcard.width - 6) / Object.keys(wcard.modelData.colors ?? { a: 1 }).length
                                                height: 4
                                                color: modelData
                                            }
                                        }
                                    }
                                    Txt {
                                        x: 10
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 7
                                        width: parent.width - 20
                                        text: (wcard.modelData.current ? "● " : "") + wcard.modelData.label
                                        font.pixelSize: Style.small
                                        color: wcard.modelData.colors?.bright ?? Colors.bright
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            applyWall.command = ["sh", "-c", '~/.config/rice/rice wall "$1"', "sh", wcard.modelData.name];
                                            applyWall.running = true;
                                        }
                                    }
                                }
                            }
                        }
                        Process {
                            id: applyWall
                            onExited: walls.running = true
                        }
                        Chip {
                            text: "󰸉 open the wallpaper picker"
                            onClicked: {
                                Settings.open = false;
                                Ui.openPicker();
                            }
                        }
                        // a scene wallpaper (.scene/<name>/scene.qml): its colour, a swatch or any hex
                        Option {
                            id: tintOpt
                            visible: Media.homeSceneName !== ""
                            readonly property string name: Media.homeSceneName
                            readonly property string tint: Settings.sceneTints[name] || ""
                            title: "wallpaper colour"
                            hint: "this wallpaper's colour: its own, a swatch, or any hex." + (Settings.artAccent ? " album colours still take over while music plays." : "")
                            Chip {
                                text: "own"
                                on: tintOpt.tint === ""
                                onClicked: Settings.tintScene(tintOpt.name, "")
                            }
                            Repeater {
                                model: ["#ff5a5f", "#ff6fb5", "#a66bff", "#5b8cff", "#3fd0e0", "#4ee38a", "#ffd23f", "#e8e8e8"]
                                Rectangle {
                                    required property string modelData
                                    readonly property bool on: tintOpt.tint.toLowerCase() === modelData
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: modelData
                                    border.width: on ? 2 : swatchArea.containsMouse ? 1 : 0
                                    border.color: Colors.bright
                                    scale: swatchArea.containsMouse ? 1.12 : 1
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Style.fast
                                        }
                                    }
                                    MouseArea {
                                        id: swatchArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Settings.tintScene(tintOpt.name, parent.modelData)
                                    }
                                }
                            }
                            Field {
                                width: 76
                                placeholder: "#hex"
                                text: tintOpt.tint
                                onSubmitted: t => {
                                    t = t.trim().toLowerCase();
                                    if (/^[0-9a-f]{6}$/.test(t))
                                        t = "#" + t;
                                    if (/^#[0-9a-f]{6}$/.test(t))
                                        Settings.tintScene(tintOpt.name, t);
                                }
                            }
                        }
                        Option {
                            title: "led strips"
                            hint: "DayBetter strips (~/.config/rice/leds) take the wallpaper's colour. pulse: they throb with the music's bass while a track plays."
                            Chip {
                                text: "steady"
                                on: !Settings.ledPulse
                                onClicked: Settings.set("ledPulse", false)
                            }
                            Chip {
                                text: "󰝚 pulse"
                                on: Settings.ledPulse
                                onClicked: Settings.set("ledPulse", true)
                            }
                        }
                    }

                    // ─ bar ─
                    Column {
                        visible: Settings.page === "bar"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "the bar"
                            hint: "also SUPER+Tab"
                            Chip {
                                text: Ui.barVisible ? "shown" : "hidden"
                                on: Ui.barVisible
                                onClicked: Ui.barVisible = !Ui.barVisible
                            }
                        }
                        Option {
                            title: "style"
                            hint: "one slim strip across the top, or three outlined islands"
                            Repeater {
                                model: ["strip", "islands"]
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Settings.barStyle === modelData
                                    onClicked: Settings.set("barStyle", modelData)
                                }
                            }
                        }
                        Option {
                            title: "dynamic island"
                            hint: "the middle of the bar swells to show these, then shrinks back"
                            Chip {
                                text: "volume"
                                on: Settings.osdStyle === "island"
                                onClicked: Settings.set("osdStyle", Settings.osdStyle === "island" ? "vial" : "island")
                            }
                            Chip {
                                text: "tracks"
                                on: Settings.islandTracks
                                onClicked: Settings.set("islandTracks", !Settings.islandTracks)
                            }
                            Chip {
                                text: "notifications"
                                on: Settings.islandNotifs
                                onClicked: Settings.set("islandNotifs", !Settings.islandNotifs)
                            }
                            Chip {
                                text: "claude"
                                on: Settings.islandClaude
                                onClicked: Settings.set("islandClaude", !Settings.islandClaude)
                            }
                        }
                        Option {
                            title: "window title"
                            hint: "the focused window's name, next to the workspaces"
                            Chip {
                                text: Settings.barTitle ? "on" : "off"
                                on: Settings.barTitle
                                onClicked: Settings.set("barTitle", !Settings.barTitle)
                            }
                        }
                        Option {
                            title: "now playing"
                            hint: "the song, next to the clock"
                            Chip {
                                text: Settings.barMedia ? "on" : "off"
                                on: Settings.barMedia
                                onClicked: Settings.set("barMedia", !Settings.barMedia)
                            }
                        }
                        Option {
                            title: "cpu and memory"
                            hint: "the two little meters on the right"
                            Chip {
                                text: Settings.barMeters ? "on" : "off"
                                on: Settings.barMeters
                                onClicked: Settings.set("barMeters", !Settings.barMeters)
                            }
                        }
                    }

                    // ─ widgets ─
                    Column {
                        visible: Settings.page === "widgets"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "desktop widgets"
                            hint: Widgets.items.filter(i => i.board === "desktop").length + " placed  ·  right-click the desktop to add  ·  SUPER+W"
                            Chip {
                                text: "󰏫 edit"
                                onClicked: {
                                    Settings.open = false;
                                    Widgets.edit("desktop");
                                }
                            }
                        }
                        Option {
                            title: "depth"
                            hint: "the widgets float over the wallpaper: they lean away from the pointer (near ones more), cast shadows, and sink back while windows are open. each widget's own depth is in its settings. paused in performance mode."
                            Chip {
                                text: "off"
                                on: !Settings.depth
                                onClicked: Settings.set("depth", false)
                            }
                            Chip {
                                text: "󰆧 on"
                                on: Settings.depth
                                onClicked: Settings.set("depth", true)
                            }
                        }
                        Option {
                            title: "as the windows scroll"
                            hint: ({ parallax: "the widgets drift behind the row of windows, slower, like a far-off layer", canvas: "the widgets sit on the row itself and scroll away with the windows", pinned: "the widgets stay put on the screen" })[Settings.canvasWidgets] ?? ""
                            Repeater {
                                model: ["parallax", "canvas", "pinned"]
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Settings.canvasWidgets === modelData
                                    onClicked: Settings.set("canvasWidgets", modelData)
                                }
                            }
                        }
                        Option {
                            title: "lock screen widgets"
                            hint: Widgets.items.filter(i => i.board === "lock").length + " placed  ·  they can float on the liquid"
                            Chip {
                                text: "󰌾 edit"
                                onClicked: {
                                    Settings.open = false;
                                    Lock.openEditor();
                                }
                            }
                        }
                        Option {
                            title: "hide music widgets when nothing plays"
                            hint: "music, lyrics and visualizer widgets step aside until there's a song"
                            Chip {
                                text: Settings.hideIdleMusic ? "on" : "off"
                                on: Settings.hideIdleMusic
                                onClicked: Settings.set("hideIdleMusic", !Settings.hideIdleMusic)
                            }
                        }
                        Option {
                            title: "snap to the grid"
                            hint: "while moving and resizing widgets"
                            Chip {
                                text: Widgets.snap ? "on" : "off"
                                on: Widgets.snap
                                onClicked: Widgets.snap = !Widgets.snap
                            }
                        }
                    }

                    // ─ lock ─
                    Column {
                        visible: Settings.page === "lock"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "music underwater"
                            hint: "while the lock screen's up, whatever's playing sounds muffled, like it's under the liquid"
                            Chip {
                                text: Settings.lockMuffle ? "on" : "off"
                                on: Settings.lockMuffle
                                onClicked: Settings.set("lockMuffle", !Settings.lockMuffle)
                            }
                        }
                        Option {
                            title: "idle tide"
                            hint: Settings.idleTide ? "after " + Settings.idleAfter + " minutes away the liquid rises over your windows, filling the screen in " + Settings.tideRise + " s, then locks. touch anything and it drains. a playing video holds it back." : "off: the screen never locks by itself"
                            Chip {
                                text: Settings.idleTide ? "on" : "off"
                                on: Settings.idleTide
                                onClicked: Settings.set("idleTide", !Settings.idleTide)
                            }
                            Chip {
                                text: "▶ try"
                                onClicked: {
                                    Settings.open = false;
                                    Tide.rise(true);
                                }
                            }
                        }
                        Option {
                            visible: Settings.idleTide
                            title: "rises after"
                            hint: "minutes without the keyboard or mouse"
                            Repeater {
                                model: Settings.idleAfters
                                Chip {
                                    required property int modelData
                                    text: modelData + " min"
                                    on: Settings.idleAfter === modelData
                                    onClicked: Settings.set("idleAfter", modelData)
                                }
                            }
                        }
                        Option {
                            visible: Settings.idleTide
                            title: "takes"
                            hint: "how long it rises before it locks: time to notice it"
                            Repeater {
                                model: Settings.tideRises
                                Chip {
                                    required property int modelData
                                    text: modelData + " s"
                                    on: Settings.tideRise === modelData
                                    onClicked: Settings.set("tideRise", modelData)
                                }
                            }
                        }
                        Option {
                            title: "lock screen"
                            hint: "glowing liquid with your widgets floating on it. SUPER+Escape locks."
                            Chip {
                                text: "󰈈 preview"
                                onClicked: {
                                    Settings.open = false;
                                    Lock.openEditor();
                                    Widgets.editing = false;
                                }
                            }
                            Chip {
                                text: "󰌾 lock now"
                                onClicked: {
                                    Settings.open = false;
                                    Quickshell.execDetached(["sh", "-c", "~/.config/rice/rice lock"]);
                                }
                            }
                        }
                    }

                    // ─ sound ─
                    Column {
                        visible: Settings.page === "sound"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "little sounds"
                            hint: "bubbles when unlocking, a click for screenshots, a tick for volume."
                            Chip {
                                text: Settings.sounds ? "󰕾 on" : "off"
                                on: Settings.sounds
                                onClicked: Settings.set("sounds", !Settings.sounds)
                            }
                            Chip {
                                text: "▶ try"
                                onClicked: {
                                    const was = Settings.sounds;
                                    Settings.sounds = true;
                                    Sounds.play("bubble");
                                    Settings.sounds = was;
                                }
                            }
                        }
                        Option {
                            title: "lock screen sounds"
                            hint: "the liquid sounds like water as it moves: pouring in as it locks, a drop for every key, a splash for a wrong password, draining away as it unlocks."
                            Chip {
                                text: Settings.lockSounds ? "󰕾 on" : "off"
                                on: Settings.lockSounds
                                onClicked: Settings.set("lockSounds", !Settings.lockSounds)
                            }
                            Chip {
                                text: "▶ try"
                                onClicked: Lock.openPreview(false)
                            }
                        }
                        Option {
                            title: "notification sounds"
                            hint: "a sound as a notification arrives, in the island or as a popup (never in do-not-disturb)."
                            Chip {
                                text: Settings.notifSounds ? "󰕾 on" : "off"
                                on: Settings.notifSounds
                                onClicked: Settings.set("notifSounds", !Settings.notifSounds)
                            }
                        }
                        Option {
                            visible: Settings.notifSounds
                            title: "their style"
                            hint: (Settings.notifStyle === "drip" ? "a drop of water" : "the " + Settings.notifStyle + " terminal style's opening sound") + ". click one to hear it."
                            Repeater {
                                model: Settings.notifStyles
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Settings.notifStyle === modelData
                                    onClicked: {
                                        Settings.set("notifStyle", modelData);
                                        Sounds.out(Sounds.notifSound(modelData), 1);
                                    }
                                }
                            }
                        }
                        Option {
                            title: "terminal sounds"
                            hint: "a sound as a terminal opens, another as one closes."
                            Chip {
                                text: Settings.termSounds ? "󰕾 on" : "off"
                                on: Settings.termSounds
                                onClicked: Settings.set("termSounds", !Settings.termSounds)
                            }
                        }
                        Option {
                            visible: Settings.termSounds
                            title: "their style"
                            hint: ({
                                    mine: "your own clips (TermOpen and TermClose in ~/sounds)",
                                    ps2: "the cold console menu: a swell breathing in to a deep boom and glass, sliding down as it closes",
                                    hud: "a cyberpunk HUD: an FM zap and robotic beeps",
                                    crt: "an old monitor: power-on static and whine, the zwip as it shuts off",
                                    glitch: "a gated, stuttering digital buzz"
                                })[Settings.termStyle] + ". click one to hear it (open, then close)."
                            Repeater {
                                model: Settings.termStyles
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Settings.termStyle === modelData
                                    onClicked: {
                                        Settings.set("termStyle", modelData);
                                        Sounds.preview(modelData);
                                    }
                                }
                            }
                        }
                        Option {
                            visible: Settings.sounds || Settings.termSounds || Settings.notifSounds || Settings.lockSounds
                            title: "their volume"
                            hint: Math.round(Settings.soundVolume * 100) + "%"
                            SegSlider {
                                width: 200
                                segments: 20
                                value: Settings.soundVolume
                                onMoved: v => Settings.set("soundVolume", v)
                            }
                        }
                        Option {
                            title: "volume"
                            hint: (Audio.sink?.description ?? "").toLowerCase()
                            SegSlider {
                                width: 240
                                segments: 24
                                value: Audio.volume
                                onMoved: v => Audio.setVolume(v)
                            }
                        }
                        Option {
                            title: "equaliser"
                            hint: "10 bands on everything that's playing. preset: " + Eq.preset
                            Chip {
                                text: Eq.on ? "󰺢 on" : "off"
                                on: Eq.on
                                onClicked: Eq.toggle()
                            }
                            Chip {
                                text: "open the eq"
                                onClicked: {
                                    Settings.open = false;
                                    Quickshell.execDetached(["qs", "-c", "ekitai", "ipc", "call", "music", "eq"]);
                                }
                            }
                        }
                        Flow {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: Eq.presets
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    on: Eq.preset === modelData
                                    onClicked: Eq.usePreset(modelData)
                                }
                            }
                        }
                    }

                    // ─ notifications ─
                    Column {
                        visible: Settings.page === "notifications"
                        width: parent.width
                        spacing: 16
                        Option {
                            title: "do not disturb"
                            hint: "no popups; they still go to the history"
                            Chip {
                                text: Ui.dnd ? "on" : "off"
                                on: Ui.dnd
                                onClicked: Ui.dnd = !Ui.dnd
                            }
                        }
                        Option {
                            title: "history"
                            hint: Notifs.count + " in the control centre"
                            Chip {
                                text: "clear"
                                onClicked: Notifs.clear()
                            }
                        }
                    }

                    // ─ about ─
                    Column {
                        visible: Settings.page === "about"
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: [["user", Sys.user + "@" + Sys.host], ["system", Sys.os], ["kernel", Sys.kernel], ["cpu", Sys.cpuModel], ["up", Sys.uptime], ["shell", "ekitai (quickshell) · " + Look.shape + (Look.glass ? " · glass" : "")]]
                            RowLayout {
                                required property var modelData
                                width: parent.width
                                Txt {
                                    Layout.preferredWidth: 90
                                    text: modelData[0]
                                    color: Colors.mid
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    text: modelData[1]
                                    color: Colors.bright
                                }
                            }
                        }
                        Item {
                            width: 1
                            height: 12
                        }
                        Txt {
                            text: "KEYS"
                            font.pixelSize: Style.small
                            font.letterSpacing: 2
                            color: Colors.mid
                        }
                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 5
                            Repeater {
                                model: Binds.list
                                RowLayout {
                                    required property var modelData
                                    width: (pageCol.width - 24) / 2
                                    Frame {
                                        pill: true
                                        implicitWidth: keyText.implicitWidth + 14
                                        implicitHeight: 20
                                        color: Colors.bg2
                                        Txt {
                                            id: keyText
                                            anchors.centerIn: parent
                                            text: modelData[0]
                                            font.pixelSize: Style.small
                                            font.bold: true
                                            color: Colors.accent
                                        }
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        text: modelData[1]
                                        font.pixelSize: Style.small
                                        color: Colors.bright
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function move(d) {
        const i = pages.findIndex(p => p[0] === Settings.page);
        Settings.page = pages[(i + d + pages.length) % pages.length][0];
    }

    // a setting: its name and a line about it on the left, its controls on the right
    component Option: RowLayout {
        id: opt
        property string title
        property string hint
        default property alias controls: ctl.data
        width: parent?.width ?? 0
        spacing: 12
        Column {
            Layout.fillWidth: true
            spacing: 2
            Txt {
                text: opt.title
                font.bold: true
                color: Colors.bright
            }
            Txt {
                width: parent.width
                text: opt.hint
                wrapMode: Text.WordWrap
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }
        Row {
            id: ctl
            spacing: 4
        }
    }
}

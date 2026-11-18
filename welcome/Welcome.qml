import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components
import qs.picker

// The first-run welcome: on the first login (once the lock's intro is unlocked), the liquid rises over
// the wallpaper and four steps float on it: hello, pick a wallpaper (it applies live, so the colours
// change behind you), pick square / round / squiggle (and glass), then the keys. The liquid rises a
// little with every step; "start" drains it. It shows once: ~/.local/state/ekitai/welcomed marks it done.
//   ←/→ choose · Enter next (or apply) · Backspace back · Esc skip
//   qs -c ekitai ipc call welcome open        see it again
PanelWindow {
    id: win

    property bool open: false
    property int step: 0
    readonly property var steps: ["hello", "wallpaper", "shape", "keys"]

    // ── first run? ──
    readonly property string flag: Quickshell.env("HOME") + "/.local/state/ekitai/welcomed"
    property bool firstRun: false
    FileView {
        path: win.flag
        printErrors: false
        onLoadFailed: win.firstRun = true
    }
    // give the login a moment (the boot lock may still be on its way), then wait for it to be unlocked
    Timer {
        id: settle
        interval: 2500
        running: win.firstRun
        onTriggered: win.maybeShow()
    }
    Connections {
        target: Lock
        function onLockedChanged() {
            if (!Lock.locked && win.firstRun)
                settle.restart();
        }
    }
    function maybeShow() {
        if (firstRun && !Lock.locked && !open)
            show();
    }

    function show() {
        step = 0;
        walls.running = true;
        open = true;
    }

    function finish() {
        firstRun = false;
        open = false;
        Quickshell.execDetached(["sh", "-c", `mkdir -p "$(dirname "$1")" && touch "$1"`, "sh", flag]);
    }

    function next() {
        if (step === steps.length - 1)
            finish();
        else
            go(step + 1);
    }
    function go(s) {
        if (s < 0 || s >= steps.length || s === step)
            return;
        step = s;
        pool.ripple(width * (0.2 + 0.6 * Math.random()), 0.6);
        stir.restart();
    }


    // ── the liquid: floods in, rises a little each step, drains at the end ──
    property real fill: 0
    property real t: 0
    property real rough: 1
    readonly property var levels: [0.1, 0.17, 0.24, 0.31]
    property real stepLevel: levels[step]
    Behavior on stepLevel {
        SpringAnimation {
            spring: 2.2
            damping: 0.25
            epsilon: 0.001
        }
    }

    onOpenChanged: {
        if (open) {
            drain.stop();
            flood.start();
            keys.forceActiveFocus();
        } else {
            flood.stop();
            drain.start();
            pool.ripple(width / 2, 1);
        }
    }
    ParallelAnimation {
        id: flood
        NumberAnimation {
            target: win
            property: "fill"
            to: 1
            duration: 1100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: win
            property: "rough"
            from: 1
            to: 0
            duration: 2200
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: win
            property: "t"
            to: 1
            duration: Style.slow
            easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: drain
        NumberAnimation {
            target: win
            property: "fill"
            to: 0
            duration: 600
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: win
            property: "t"
            to: 0
            duration: 600
            easing.type: Easing.InCubic
        }
    }
    NumberAnimation {                            // a step stirs the surface, then it settles
        id: stir
        target: win
        property: "rough"
        from: 0.5
        to: 0
        duration: 1400
        easing.type: Easing.OutQuad
    }

    screen: Ui.screen
    visible: t > 0 || fill > 0.001
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ekitai-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── the wallpapers (`rice walls --json`, as the picker) ──
    property var themes: []
    property int wallCursor: 0
    property string applied: ""                  // the one picked here
    Process {
        id: walls
        command: ["sh", "-c", "~/.config/rice/rice walls --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.themes = JSON.parse(text);
                } catch (e) {
                    win.themes = [];
                }
                const cur = win.themes.findIndex(t => t.current);
                win.wallCursor = Math.max(0, cur);
                win.applied = win.themes[cur]?.name ?? "";
            }
        }
    }
    Process {
        id: applier
    }
    function applyWall(i) {
        const w = themes[i];
        if (!w)
            return;
        wallCursor = i;
        if (w.name === applied || applier.running)
            return;
        applied = w.name;
        applier.command = ["sh", "-c", "~/.config/rice/rice wall \"$1\"", "sh", w.name];
        applier.running = true;
        pool.ripple(width / 2, 0.8);
    }

    // ── keys ──
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key, s = win.steps[win.step];
            const left = k === Qt.Key_Left || k === Qt.Key_H, right = k === Qt.Key_Right || k === Qt.Key_L;
            if (k === Qt.Key_Escape)
                win.finish();
            else if (k === Qt.Key_Backspace)
                win.go(win.step - 1);
            else if (s === "wallpaper" && (left || right))
                win.wallCursor = Math.max(0, Math.min(win.themes.length - 1, win.wallCursor + (right ? 1 : -1)));
            else if (s === "shape" && (left || right)) {
                const i = Look.shapes.indexOf(Look.shape) + (right ? 1 : -1);
                Look.set(Look.shapes[Math.max(0, Math.min(Look.shapes.length - 1, i))]);
            } else if (s === "shape" && k === Qt.Key_G)
                Look.setGlass(!Look.glass);
            else if (left)
                win.go(win.step - 1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || right) {
                // on the wallpaper step, Enter applies the highlighted one first
                if (s === "wallpaper" && win.themes[win.wallCursor] && win.themes[win.wallCursor].name !== win.applied)
                    win.applyWall(win.wallCursor);
                else
                    win.next();
            } else
                return;
            e.accepted = true;
        }
    }

    // ── the picture ──
    Pool {
        id: pool
        anchors.fill: parent
        opacity: win.t
        level: win.stepLevel * win.fill
        rough: win.rough
        dim: 0.5
    }

    // the pages float a little on the waves, and slide in from the side
    Item {
        id: stage
        anchors.fill: parent
        opacity: win.t
        transform: Translate {
            y: (1 - win.t) * 30 + pool.swell(win.width / 2) * 0.15
        }

        // ── 1. hello ──
        Page {
            index: 0
            Column {
                anchors.centerIn: parent
                spacing: 10
                Logo {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 170
                    height: 170
                    color: Colors.bright
                    live: true
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "e k i t a i"
                    font.pixelSize: Style.px(22)
                    font.letterSpacing: 6
                    color: Colors.accent
                }
                Item {
                    width: 1
                    height: 18
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "welcome. three quick choices and you're in"
                    color: Colors.bright
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "a wallpaper (your colours come from it), a shape, and the keys worth knowing"
                    color: Colors.mid
                }
                Item {
                    width: 1
                    height: 22
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: "begin"
                    onClicked: win.next()
                }
            }
        }

        // ── 2. wallpaper ──
        Page {
            index: 1
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 14
                Heading {
                    title: "pick a wallpaper"
                    sub: "the whole desktop takes its colours from it. change it any time with SUPER T"
                }
                Item {
                    width: 1
                    height: 10
                }
                Row {
                    id: cards
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 34
                    readonly property real cardW: Math.min(300, (win.width * 0.8 - spacing * (win.themes.length - 1)) / Math.max(1, win.themes.length))
                    Repeater {
                        model: win.themes
                        WallCard {
                            required property var modelData
                            required property int index
                            wall: modelData
                            number: index + 1
                            width: cards.cardW
                            selected: index === win.wallCursor
                            scale: selected ? 1.04 : 0.96
                            opacity: selected ? 1 : 0.6
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Style.med
                                    easing.type: Easing.OutCubic
                                }
                            }
                            onPicked: win.applyWall(index)
                        }
                    }
                }
                Item {
                    width: 1
                    height: 6
                }
                // the highlighted one: its name and the colours it gives
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    readonly property var w: win.themes[win.wallCursor] ?? null
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (parent.w?.label ?? parent.w?.name ?? "").toLowerCase()
                        font.pixelSize: Style.px(22)
                        color: Colors.bright
                    }
                    Repeater {
                        model: ["accent", "accent2", "bright", "dim"]
                        Frame {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            blob: true
                            width: 14
                            height: 14
                            color: parent.w?.colors?.[modelData] ?? "transparent"
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.w && parent.w.name === win.applied ? "  ✓ applied" : "  enter / click applies"
                        color: Colors.mid
                    }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "add your own pictures to ~/Pictures/wallpapers"
                    color: Colors.dim
                }
            }
        }

        // ── 3. shape ──
        Page {
            index: 2
            Column {
                anchors.centerIn: parent
                spacing: 14
                Heading {
                    title: "pick a shape"
                    sub: "every panel, button and window follows it. try them, it changes as you click"
                }
                Item {
                    width: 1
                    height: 10
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24
                    Repeater {
                        model: Look.shapes
                        ShapeCard {
                            required property string modelData
                            shape: modelData
                        }
                    }
                }
                Item {
                    width: 1
                    height: 6
                }
                // glass: on / off
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "glass"
                        color: Colors.bright
                    }
                    Repeater {
                        model: [false, true]
                        Frame {
                            id: g
                            required property bool modelData
                            readonly property bool on: Look.glass === modelData
                            pill: true
                            width: 52
                            height: 22
                            color: on ? Colors.accent : gArea.containsMouse ? Colors.bg3 : Colors.bg2
                            Txt {
                                anchors.centerIn: parent
                                text: g.modelData ? "on" : "off"
                                color: g.on ? Colors.bg : Colors.mid
                            }
                            MouseArea {
                                id: gArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Look.setGlass(g.modelData)
                            }
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "  see-through, frosted panels (g)"
                        color: Colors.mid
                    }
                }
            }
        }

        // ── 4. keys ──
        Page {
            index: 3
            Column {
                anchors.centerIn: parent
                spacing: 14
                Heading {
                    title: "the keys worth knowing"
                    sub: "these are in settings → about too (SUPER I)"
                }
                Item {
                    width: 1
                    height: 8
                }
                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 8
                    Repeater {
                        model: Binds.list
                        Row {
                            required property var modelData
                            width: 300
                            spacing: 12
                            Frame {
                                pill: true
                                width: 118
                                height: 22
                                color: Colors.bg2
                                Txt {
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    color: Colors.accent
                                }
                            }
                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                color: Colors.bright
                            }
                        }
                    }
                }
                Item {
                    width: 1
                    height: 14
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: "start"
                    onClicked: win.finish()
                }
            }
        }
    }

    // ── progress: liquid dots, the current one stretched (like the bar's workspaces) ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        spacing: 12
        opacity: win.t
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: win.steps.length
                Frame {
                    id: dot
                    required property int index
                    pill: true
                    width: index === win.step ? 30 : 9
                    height: 9
                    color: index === win.step ? Colors.accent : index < win.step ? Colors.mid : Colors.faint
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.med
                            easing.type: Easing.OutCubic
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.go(dot.index)
                    }
                }
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                    hello: "enter  begin   ·   esc  skip",
                    wallpaper: "←/→  choose   ·   enter  apply, then next   ·   backspace  back   ·   esc  skip",
                    shape: "←/→  choose   ·   g  glass   ·   enter  next   ·   backspace  back   ·   esc  skip",
                    keys: "enter  start   ·   backspace  back"
                })[win.steps[win.step]]
            color: Colors.bright
        }
    }

    // ── pieces ──
    // a step: centred, sliding in from the side it's on
    component Page: Item {
        property int index
        readonly property int off: index - win.step
        width: stage.width
        height: stage.height
        opacity: off === 0 ? 1 : 0
        visible: opacity > 0.01
        x: off * 80
        enabled: off === 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.med
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: Style.slow
                easing.type: Easing.OutCubic
            }
        }
    }

    component Heading: Column {
        property string title
        property string sub
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.title
            font.pixelSize: Style.px(33)
            color: Colors.bright
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.sub
            color: Colors.mid
        }
    }

    component Button: Frame {
        id: btn
        property string label
        signal clicked
        pill: true
        width: btnText.implicitWidth + 40
        height: 34
        color: btnArea.containsMouse ? Colors.bright : Colors.accent
        Txt {
            id: btnText
            anchors.centerIn: parent
            text: btn.label + "   ⏎"
            color: Colors.bg
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // a shape to pick, drawn in that shape whatever the current one is: a panel, a pill and a button
    component ShapeCard: Item {
        id: sc
        property string shape
        readonly property bool on: Look.shape === shape
        readonly property real r: shape === "square" ? 0 : 14
        width: 190
        height: 170
        scale: on ? 1.04 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Style.med
                easing.type: Easing.OutCubic
            }
        }

        // the card
        Rectangle {
            anchors.fill: parent
            visible: sc.shape !== "squiggle"
            radius: sc.r
            color: Colors.glass
            border.width: sc.on ? 2 : 1
            border.color: sc.on ? Colors.accent : scArea.containsMouse ? Colors.mid : Colors.faint
        }
        Frame {
            anchors.fill: parent
            visible: sc.shape === "squiggle"
            wavy: true
            radius: 14
            color: Colors.glass
            border.width: sc.on ? 2 : 1
            border.color: sc.on ? Colors.accent : scArea.containsMouse ? Colors.mid : Colors.faint
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 10
            // a little panel
            Item {
                width: 130
                height: 56
                Rectangle {
                    anchors.fill: parent
                    visible: sc.shape !== "squiggle"
                    radius: sc.r * 0.8
                    color: Colors.bg2
                }
                Frame {
                    anchors.fill: parent
                    visible: sc.shape === "squiggle"
                    wavy: true
                    radius: 11
                    color: Colors.bg2
                }
                Rectangle {                      // a bar inside it
                    x: 12
                    y: 14
                    width: 70
                    height: 8
                    radius: sc.shape === "square" ? 0 : 4
                    color: Colors.accent
                }
                Rectangle {
                    x: 12
                    y: 32
                    width: 100
                    height: 8
                    radius: sc.shape === "square" ? 0 : 4
                    color: Colors.dim
                }
            }
            // a pill and a button
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Rectangle {
                    width: 70
                    height: 22
                    radius: sc.shape === "square" ? 0 : 11
                    color: Colors.accent
                }
                Item {
                    width: 24
                    height: 24
                    Rectangle {
                        anchors.fill: parent
                        visible: sc.shape !== "squiggle"
                        radius: sc.shape === "square" ? 0 : 12
                        color: Colors.mid
                    }
                    Frame {
                        anchors.fill: parent
                        visible: sc.shape === "squiggle"
                        blob: true
                        wavy: true
                        color: Colors.mid
                    }
                }
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: sc.shape
            color: sc.on ? Colors.bright : Colors.mid
        }
        MouseArea {
            id: scArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Look.set(sc.shape)
        }
    }
}

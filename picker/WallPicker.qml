import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// The wallpaper picker (SUPER+T): the theme's own wallpaper and every image in ~/Pictures/wallpapers,
// each as a card drawn in the palette it would give (the theme turned to the image's main colour).
// Picking one closes the picker and runs `rice wall <image>`: the wallpaper wipes up and the colours crossfade.
//   ←/→ h/l or scroll = move · 1-9 = jump · Enter / click = apply · Esc = close
PanelWindow {
    id: win

    readonly property bool open: Ui.picker
    property real t: open ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: win.open ? Style.med : Style.fast
            easing.type: Easing.OutCubic
        }
    }

    screen: Ui.screen
    visible: t > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ekitai-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── wallpapers (from `rice walls --json`) ─────────────
    property var themes: []
    readonly property int count: themes.length
    property int cursor: 0                       // unbounded, so the carousel can loop forever
    readonly property int sel: count ? ((cursor % count) + count) % count : 0
    readonly property var chosen: themes[sel] ?? null
    property bool instant: true                  // no slide when it first opens on the current rice
    property real pos: cursor
    Behavior on pos {
        enabled: !win.instant
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", "~/.config/rice/rice walls --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.themes = JSON.parse(text);
                } catch (e) {
                    win.themes = [];
                }
                win.instant = true;
                win.cursor = Math.max(0, win.themes.findIndex(t => t.current));
                Qt.callLater(() => win.instant = false);
            }
        }
    }

    onOpenChanged: {
        if (open) {
            lister.running = true;
            keys.forceActiveFocus();
        }
    }

    function move(step) {
        if (count && !applying)
            cursor += step;
    }

    function jump(i) {
        if (i < 0 || i >= count || applying)
            return;
        // the short way round the loop
        let d = i - sel;
        if (d > count / 2)
            d -= count;
        if (d < -count / 2)
            d += count;
        cursor += d;
    }

    // ── applying: close, and let the desktop do the change (the wallpaper wipes up, the colours crossfade) ──
    property var applying: null

    function apply() {
        if (!chosen || applying)
            return;
        applying = chosen;
        runner.command = ["sh", "-c", "~/.config/rice/rice wall \"$1\"", "sh", chosen.name];
        runner.running = true;
        Ui.picker = false;
    }

    Process {
        id: runner
        onExited: win.applying = null
    }

    IpcHandler {
        target: "wall"
        function toggle(): void {
            Ui.picker ? Ui.picker = false : Ui.openPicker();
        }
    }

    // ── keys ──────────────────────────────────────────────
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_H || e.key === Qt.Key_Backtab)
                win.move(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Tab)
                win.move(1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                win.apply();
            else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q)
                Ui.picker = false;
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9)
                win.jump(e.key - Qt.Key_1);
            else
                return;
            e.accepted = true;
        }
    }

    // ── backdrop: black, with faint CRT scanlines ─────────
    Item {
        anchors.fill: parent
        opacity: win.t

        Rectangle {
            anchors.fill: parent
            color: Colors.bg
            opacity: 0.96
        }
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = Qt.alpha(Colors.accent, 0.05);
                for (let y = 0; y < height; y += 3)
                    c.fillRect(0, y, width, 1);
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.picker = false
            onWheel: w => win.move(w.angleDelta.y > 0 || w.angleDelta.x > 0 ? -1 : 1)
        }
    }

    // ── the prompt ────────────────────────────────────────
    Frame {
        id: prompt
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.1) - (1 - win.t) * 16
        opacity: win.t
        width: promptRow.implicitWidth + 2
        height: 36
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        RowLayout {
            id: promptRow
            x: 1
            height: parent.height
            spacing: 0
            Rectangle {
                Layout.preferredWidth: Look.round ? 30 : 36
                Layout.preferredHeight: Look.round ? 30 : 34
                Layout.margins: Look.round ? 3 : 1
                radius: Look.round ? 15 : 0
                color: Colors.accent
                Logo {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    color: Colors.bg
                }
            }
            Txt {
                Layout.leftMargin: 12
                text: "❯ wall " + (win.chosen?.label ?? "")
                font.pixelSize: Style.px(Style.big)
                color: Colors.bright
            }
            Rectangle {                          // the cursor
                Layout.preferredWidth: 8
                Layout.preferredHeight: 16
                Layout.leftMargin: 2
                color: Colors.accent
                SequentialAnimation on opacity {
                    running: win.open
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0
                        duration: 0
                    }
                    PauseAnimation {
                        duration: 530
                    }
                    NumberAnimation {
                        to: 1
                        duration: 0
                    }
                    PauseAnimation {
                        duration: 530
                    }
                }
            }
            Txt {
                Layout.leftMargin: 28
                Layout.rightMargin: 14
                text: "[" + (win.sel + 1) + "/" + win.count + "]  now: " + (win.themes.find(t => t.current)?.label ?? "—")
                font.pixelSize: Style.small
                color: Colors.mid
            }
        }
    }

    // ── the carousel ──────────────────────────────────────
    readonly property real cardW: Math.round(Math.min(560, width * 0.34))

    Item {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 10
        width: parent.width
        height: win.cardW * 0.7
        opacity: win.t
        scale: 0.94 + 0.06 * win.t

        Repeater {
            id: cards
            model: win.themes

            WallCard {
                required property var modelData
                required property int index

                wall: modelData
                number: index + 1
                selected: index === win.sel
                width: win.cardW

                // offset from the middle, wrapped so the carousel loops: …, -1, 0, +1, …
                readonly property real off: {
                    const n = win.count;
                    let d = (((index - win.pos) % n) + n) % n;
                    return d > n / 2 ? d - n : d;
                }
                readonly property real a: Math.abs(off)

                x: stage.width / 2 - width / 2 + off * win.cardW * 0.82
                y: (stage.height - height) / 2
                z: 10 - a
                scale: 1 - 0.18 * Math.min(1, a)
                // past one step out (where the loop wraps round) a card fades away, so it never visibly jumps
                opacity: a <= 1 ? 1 - 0.55 * a : Math.max(0, 0.45 * (1.5 - a) / 0.5)
                visible: opacity > 0.01
                near: a < 2.5                            // only nearby cards load their image

                onPicked: index === win.sel ? win.apply() : win.jump(index)
            }
        }
    }

    // ── the selected one: its name and the colours it gives ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height + 26
        opacity: win.t
        spacing: 10
        readonly property var c: win.chosen?.colors ?? ({})

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (win.chosen?.label ?? "") + (win.chosen?.current ? "  ●" : "")
            font.pixelSize: Style.px(22)
            color: parent.c.bright ?? Colors.bright
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !win.chosen ? "" : win.chosen.own ? "hand-tuned palette" : win.chosen.mono ? "no colour in it: greys" : "colours from the image  ·  hue " + win.chosen.hue + "°"
            color: parent.c.accent ?? Colors.mid
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var list: [...Object.values(parent.c), ...(win.chosen?.term ?? [])]
            Repeater {
                model: parent.list
                Rectangle {
                    required property var modelData
                    width: 16
                    height: 6
                    color: modelData
                }
            }
        }
    }

    // ── key hints + position dots ─────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.08)
        opacity: win.t
        spacing: 10

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: win.count
                Rectangle {
                    required property int index
                    width: index === win.sel ? 22 : 8
                    height: 4
                    color: index === win.sel ? Colors.accent : Colors.dim
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.med
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "←/→  move   ·   enter  " + (win.chosen?.current ? "reapply" : "apply") + "   ·   esc  close   ·   add your own to ~/Pictures/wallpapers"
            font.pixelSize: Style.small
            color: Colors.mid
        }
    }
}

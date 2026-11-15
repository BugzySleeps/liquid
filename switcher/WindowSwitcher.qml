import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// ALT+Tab: your windows, most recently used first, as a carousel of live previews (the picker's look).
// Hold ALT and tap Tab to move (SHIFT+Tab back), let go of ALT to switch. Enter / click also switch,
// Esc cancels. Only the selected window's preview runs live; the rest are still frames.
//   qs -c ekitai ipc call switcher next | prev | close
PanelWindow {
    id: win

    property bool open: false
    property var wins: []                        // [{ address, cls, title, ws, top (HyprlandToplevel) }]
    property int cursor: 0
    readonly property int count: wins.length
    readonly property int sel: count ? ((cursor % count) + count) % count : 0
    readonly property var chosen: wins[sel] ?? null
    property bool instant: true
    property real pos: cursor
    Behavior on pos {
        enabled: !win.instant
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

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
    WlrLayershell.namespace: "ekitai-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function step(d) {
        if (!open) {
            pending = d;
            lister.running = true;               // opens once the window list is in
            return;
        }
        cursor += d;
    }
    property int pending: 1

    // the windows, most recently used first (hyprctl knows the focus history)
    Process {
        id: lister
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                const tops = Hyprland.toplevels.values;
                const norm = a => String(a).replace(/^0x/, "");
                win.wins = list.filter(c => c.mapped !== false && c.workspace?.id !== undefined)
                    .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                    .map(c => ({
                        address: c.address,
                        cls: c.class || c.initialClass || "",
                        title: c.title || c.class || "",
                        ws: c.workspace.id > 0 ? String(c.workspace.id) : (c.workspace.name || "").replace("special:", ""),
                        top: tops.find(t => norm(t.address) === norm(c.address)) ?? null
                    }));
                if (win.wins.length < 2 && win.pending > 0)
                    return;                      // nothing to switch to
                win.instant = true;
                win.cursor = win.wins.length > 1 ? (win.pending > 0 ? 1 : win.wins.length - 1) : 0;
                Qt.callLater(() => win.instant = false);
                win.open = true;
                keys.forceActiveFocus();
            }
        }
    }

    function commit() {
        if (!open)
            return;
        const c = chosen;
        open = false;
        if (c)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${c.address}" })`);
    }

    IpcHandler {
        target: "switcher"
        function next(): void {
            win.step(1);
        }
        function prev(): void {
            win.step(-1);
        }
        function close(): void {                 // without switching
            win.open = false;
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_L)
                win.step(1);
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_H)
                win.step(-1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                win.commit();
            else if (e.key === Qt.Key_Escape)
                win.open = false;
            else
                return;
            e.accepted = true;
        }
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Alt)            // let go of ALT: switch
                win.commit();
        }
    }

    // dim the screen
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        opacity: 0.6 * win.t
        MouseArea {
            anchors.fill: parent
            onClicked: win.open = false
            onWheel: w => win.step(w.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // ── the carousel ──
    readonly property real cardW: Math.round(Math.min(420, width * 0.27))

    Item {
        id: stage
        anchors.centerIn: parent
        width: parent.width
        height: win.cardW * 0.82
        opacity: win.t
        scale: 0.95 + 0.05 * win.t

        Repeater {
            model: win.wins

            Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: index === win.sel
                readonly property real off: {
                    const n = win.count;
                    let d = (((index - win.pos) % n) + n) % n;
                    return d > n / 2 ? d - n : d;
                }
                readonly property real a: Math.abs(off)
                readonly property bool near: a < 2.6

                width: win.cardW
                height: box.height
                x: stage.width / 2 - width / 2 + off * win.cardW * 0.92
                y: (stage.height - height) / 2
                z: 10 - a
                scale: 1 - 0.18 * Math.min(1, a)
                opacity: win.count < 3 ? 1 - 0.45 * Math.min(1, a) : a <= 1 ? 1 - 0.45 * a : Math.max(0, 0.55 * (1.6 - a) / 0.6)
                visible: opacity > 0.01

                Frame {
                    id: box
                    width: parent.width
                    height: col.implicitHeight + 16
                    color: Colors.glass
                    border.width: card.selected ? 2 : Style.line
                    border.color: card.selected ? Colors.accent : Colors.faint

                    Column {
                        id: col
                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 8

                        // the window itself
                        Rectangle {
                            id: shot
                            width: parent.width
                            height: Math.round(width * 10 / 16)
                            radius: Look.round ? 8 : 0
                            color: Colors.bg1
                            clip: true
                            ScreencopyView {
                                anchors.centerIn: parent
                                visible: card.near && win.open
                                captureSource: visible ? card.modelData.top?.wayland ?? null : null
                                live: card.selected
                                constraintSize: Qt.size(shot.width, shot.height)
                                width: implicitWidth
                                height: implicitHeight
                                // see-through windows (a translucent Firefox theme) would punch holes through
                                // the card; drawn into a layer first, they blend over it instead
                                layer.enabled: true
                            }
                            Txt {
                                anchors.centerIn: parent
                                visible: !card.modelData.top
                                text: "no preview"
                                color: Colors.dim
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8
                            IconImage {
                                implicitSize: 18
                                source: Quickshell.iconPath(card.modelData.cls.toLowerCase(), true) || Quickshell.iconPath(DesktopEntries.heuristicLookup(card.modelData.cls)?.icon ?? "", true) || Quickshell.iconPath("application-x-executable")
                                layer.enabled: true
                                layer.effect: Colorize {
                                    hue: Colors.accent.hslHue
                                    saturation: 0.7
                                    lightness: -0.05
                                }
                            }
                            Column {
                                Layout.fillWidth: true
                                Txt {
                                    width: parent.width
                                    text: card.modelData.title
                                    font.bold: card.selected
                                    color: card.selected ? Colors.bright : Colors.accent
                                }
                                Txt {
                                    width: parent.width
                                    text: card.modelData.cls.toLowerCase()
                                    font.pixelSize: Style.small
                                    color: Colors.mid
                                }
                            }
                            Frame {
                                pill: true
                                width: wsText.implicitWidth + 12
                                height: 20
                                color: card.selected ? Colors.accent : Colors.bg2
                                Txt {
                                    id: wsText
                                    anchors.centerIn: parent
                                    text: card.modelData.ws
                                    font.pixelSize: Style.small
                                    font.bold: true
                                    color: card.selected ? Colors.bg : Colors.mid
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.selected)
                            win.commit();
                        else
                            win.cursor += Math.round(card.off);
                    }
                }
            }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height + 24
        opacity: win.t
        text: "alt+tab next   ·   shift back   ·   let go of alt to switch   ·   esc"
        font.pixelSize: Style.small
        color: Colors.mid
    }
}

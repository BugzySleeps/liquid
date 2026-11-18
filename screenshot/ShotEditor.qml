import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// The screenshot editor (Print → drag a region → here). Draw on it, crop it, then keep it.
//   tools: 1 pen · 2 arrow · 3 box · 4 crop      colours: the swatches     Ctrl+Z undo
//   Enter save + copy · Ctrl+C copy · Ctrl+S save · Esc throw it away
// The result is rendered at the shot's own resolution.
//   qs -c ekitai ipc call shot edit <file.png>
PanelWindow {
    id: win

    property bool open: false
    property string src: ""                      // the raw grab (in $XDG_RUNTIME_DIR)
    property string tool: "pen"
    property color ink: Colors.accent
    property var marks: []                       // [{ tool, color, pts: [points] }] in display coordinates
    property var live: null                      // the mark being drawn
    property rect crop: Qt.rect(0, 0, 0, 0)       // display coordinates; empty = none
    property string busy: ""

    readonly property var inks: [Colors.accent, Colors.bright, Colors.alert, "#ffffff"]

    screen: Ui.screen
    visible: open
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ekitai-shot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function edit(path) {
        src = path;
        marks = [];
        live = null;
        crop = Qt.rect(0, 0, 0, 0);
        tool = "pen";
        busy = "";
        open = true;
        keys.forceActiveFocus();
    }

    function discard() {
        open = false;
        Quickshell.execDetached(["rm", "-f", src]);
    }

    // render the shot with its marks at full size, crop it, then save and/or copy it
    function finish(save, copy) {
        if (busy)
            return;
        busy = save ? "saving…" : "copying…";
        Sounds.play("click");
        const scale = shot.sourceSize.width / paper.width;
        const c = crop.width > 4 && crop.height > 4 ? [Math.round(crop.x * scale), Math.round(crop.y * scale), Math.round(crop.width * scale), Math.round(crop.height * scale)] : null;
        paper.grabToImage(r => {
            const out = src.replace(/\.png$/, "-edited.png");
            r.saveToFile(out);
            exporter.command = ["sh", "-c", `
                f="$1"; dir="$HOME/Pictures/Screenshots"; final="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
                if [ -n "$2" ]; then python3 -I -c 'import sys; from PIL import Image; x,y,w,h=map(int,sys.argv[2].split(",")); Image.open(sys.argv[1]).crop((x,y,x+w,y+h)).save(sys.argv[1])' "$f" "$2"; fi
                [ "$4" = 1 ] && wl-copy --type image/png < "$f"
                if [ "$3" = 1 ]; then mkdir -p "$dir"; mv "$f" "$final"; notify-send -a screenshot -i "$final" "Screenshot saved" "$final"
                else rm -f "$f"; notify-send -a screenshot "Screenshot copied"; fi
                rm -f "$5"`, "sh", out, c ? c.join(",") : "", save ? "1" : "0", copy ? "1" : "0", src];
            exporter.running = true;
        }, shot.sourceSize);
    }

    Process {
        id: exporter
        onExited: win.open = false
    }


    // ── keys ──
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape)
                win.discard();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                win.finish(true, true);
            else if (ctrl && e.key === Qt.Key_C)
                win.finish(false, true);
            else if (ctrl && e.key === Qt.Key_S)
                win.finish(true, false);
            else if (ctrl && e.key === Qt.Key_Z)
                win.marks = win.marks.slice(0, -1);
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4)
                win.tool = ["pen", "arrow", "box", "crop"][e.key - Qt.Key_1];
            else
                return;
            e.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        opacity: 0.82
    }

    // ── the shot, fitted to the screen, with the marks on top ──
    Item {
        id: paper
        readonly property real fit: Math.min((win.width * 0.86) / Math.max(1, shot.sourceSize.width), (win.height * 0.74) / Math.max(1, shot.sourceSize.height), 1.6)
        width: Math.round(shot.sourceSize.width * fit)
        height: Math.round(shot.sourceSize.height * fit)
        x: Math.round((win.width - width) / 2)
        y: Math.round((win.height - height) / 2) - 24

        Image {
            id: shot
            anchors.fill: parent
            source: win.src ? "file://" + win.src : ""
            cache: false
            smooth: true
        }

        Repeater {
            model: win.live ? [...win.marks, win.live] : win.marks
            Shape {
                required property var modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property var p: modelData.pts
                readonly property var a: p[0]
                readonly property var b: p[p.length - 1]
                ShapePath {
                    strokeColor: modelData.color
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline {
                        path: {
                            const m = modelData, p = m.pts, a = p[0], b = p[p.length - 1];
                            if (m.tool === "pen")
                                return p;
                            if (m.tool === "box")
                                return [a, Qt.point(b.x, a.y), b, Qt.point(a.x, b.y), a];
                            // arrow: the shaft, then the head
                            const ang = Math.atan2(b.y - a.y, b.x - a.x), h = 14;
                            return [a, b, Qt.point(b.x - h * Math.cos(ang - 0.45), b.y - h * Math.sin(ang - 0.45)), b, Qt.point(b.x - h * Math.cos(ang + 0.45), b.y - h * Math.sin(ang + 0.45))];
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: e => {
                keys.forceActiveFocus();
                if (win.tool === "crop")
                    win.crop = Qt.rect(e.x, e.y, 0, 0);
                else
                    win.live = { tool: win.tool, color: String(win.ink), pts: [Qt.point(e.x, e.y), Qt.point(e.x, e.y)] };
            }
            onPositionChanged: e => {
                if (!pressed)
                    return;
                const x = Math.max(0, Math.min(width, e.x)), y = Math.max(0, Math.min(height, e.y));
                if (win.tool === "crop") {
                    const x0 = win.crop.x, y0 = win.crop.y;
                    win.crop = Qt.rect(x0, y0, x - x0, y - y0);
                } else if (win.live) {
                    const l = win.live;
                    win.live = { tool: l.tool, color: l.color, pts: l.tool === "pen" ? [...l.pts, Qt.point(x, y)] : [l.pts[0], Qt.point(x, y)] };
                }
            }
            onReleased: {
                if (win.tool === "crop") {
                    const c = win.crop;           // normalise a backwards drag
                    win.crop = Qt.rect(Math.min(c.x, c.x + c.width), Math.min(c.y, c.y + c.height), Math.abs(c.width), Math.abs(c.height));
                } else if (win.live) {
                    win.marks = [...win.marks, win.live];
                    win.live = null;
                }
            }
        }
    }

    // the crop: everything outside it shaded (not part of the render)
    Item {
        anchors.fill: paper
        visible: Math.abs(win.crop.width) > 4 && Math.abs(win.crop.height) > 4
        readonly property rect r: Qt.rect(Math.min(win.crop.x, win.crop.x + win.crop.width), Math.min(win.crop.y, win.crop.y + win.crop.height), Math.abs(win.crop.width), Math.abs(win.crop.height))
        Rectangle { width: parent.width; height: parent.r.y; color: "#a0000000" }
        Rectangle { y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: "#a0000000" }
        Rectangle { y: parent.r.y; width: parent.r.x; height: parent.r.height; color: "#a0000000" }
        Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: "#a0000000" }
        Rectangle {
            x: parent.r.x
            y: parent.r.y
            width: parent.r.width
            height: parent.r.height
            color: "transparent"
            border.width: 1.5
            border.color: Colors.bright
        }
    }

    // a frame round the shot
    Frame {
        x: paper.x - 6
        y: paper.y - 6
        width: paper.width + 12
        height: paper.height + 12
        z: -1
        color: Colors.bg1
        border.width: Style.line
        border.color: Colors.faint
    }

    // ── the toolbar ──
    Frame {
        anchors.horizontalCenter: parent.horizontalCenter
        y: paper.y + paper.height + 22
        width: tools.implicitWidth + 16
        height: 40
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        RowLayout {
            id: tools
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [["pen", "󰏫", "1"], ["arrow", "󰁔", "2"], ["box", "󰹞", "3"], ["crop", "󰆞", "4"]]
                Chip {
                    required property var modelData
                    text: modelData[1] + " " + modelData[0]
                    on: win.tool === modelData[0]
                    onClicked: win.tool = modelData[0]
                }
            }
            Item {
                implicitWidth: 8
            }
            Repeater {
                model: win.inks
                Frame {
                    required property var modelData
                    blob: true
                    implicitWidth: 18
                    implicitHeight: 18
                    color: modelData
                    border.width: String(win.ink) === String(modelData) ? 2 : 0
                    border.color: Colors.bright
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.ink = parent.modelData
                    }
                }
            }
            Item {
                implicitWidth: 8
            }
            Chip {
                text: "󰕌 undo"
                onClicked: win.marks = win.marks.slice(0, -1)
            }
            Chip {
                text: "󰆏 copy"
                onClicked: win.finish(false, true)
            }
            Chip {
                text: win.busy || "󰄬 save"
                on: true
                onClicked: win.finish(true, true)
            }
            Chip {
                text: "󰅖"
                onClicked: win.discard()
            }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        y: paper.y + paper.height + 72
        text: "1-4 tools  ·  ctrl+z undo  ·  enter save + copy  ·  ctrl+c copy  ·  ctrl+s save  ·  esc throw away"
        font.pixelSize: Style.small
        color: Colors.dim
    }
}

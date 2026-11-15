import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// SUPER+O: every workspace at once, floating on the liquid. It opens like the lock: the desktop sinks
// behind the blurred wallpaper and liquid floods up from the bottom (shaders/liquid.frag), with the
// workspaces riding its surface. Each workspace holds its own pool, deeper the more windows it has.
// Drag a window (it lifts off as a droplet, stretching as it moves) onto another workspace to move it
// there: that pool rises to meet it and splashes when it lands. Click a window to focus it, a workspace
// to go to it. Arrows / hjkl pick a workspace, 1-9 jump straight to one, Enter goes, Esc closes.
// In the scrolling layout a workspace zooms out to fit its whole row, so windows off-screen show too.
// Previews are live, and the pools roll, unless performance mode is on.
//   qs -c ekitai ipc call overview toggle | open | close
PanelWindow {
    id: win

    readonly property bool open: Ui.overview
    property var clients: []                     // hyprctl clients, on regular workspaces
    property int cursor: 0                       // the selected workspace, as an index into `ids`

    // workspaces 1..n (at least 5, up to the highest in use), plus one empty one to drag windows into
    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property var ids: {
        const used = clients.map(c => c.workspace.id);
        const n = Math.min(10, Math.max(5, activeId, ...used.map(u => u + 1)));
        return Array.from({ length: n }, (_, i) => i + 1);
    }
    readonly property int count: ids.length
    readonly property int cols: count <= 4 ? count : Math.ceil(count / 2)
    readonly property int rows: Math.ceil(count / cols)

    // dragging a window: who, where, how fast, and the workspace under the pointer
    property var drag: null                      // the client
    property point dragAt: Qt.point(0, 0)
    property point vel: Qt.point(0, 0)           // pixels/second, smoothed; stretches the droplet
    property int dropId: -1

    // ── the liquid (components/Pool.qml, the lock's) ──
    property real fill: 0                        // 0 drained … 1 at rest; animated
    readonly property real level: fill * rest    // 0 empty … 1 full
    property real rough: 1                       // extra chop while it floods in
    property real t: 0                           // everything else fades in with it
    // the surface settles just under the grid, so the bottom row floats on it
    // (from the tile sizes, not grid.height, and a binding: the window has no size until it's first shown)
    readonly property real gridH: rows * (tileH + 26) + (rows - 1) * gap
    readonly property real rest: Math.max(0.12, Math.min(0.5, 1 - ((height + gridH) / 2 - 22) / Math.max(1, height)))

    FrameAnimation {
        running: win.visible
        onTriggered: {
            if (!win.drag || win.vel.x || win.vel.y)
                win.vel = Qt.point(win.vel.x * Math.pow(0.02, frameTime), win.vel.y * Math.pow(0.02, frameTime));
        }
    }

    ParallelAnimation {
        id: flood
        NumberAnimation {
            target: win
            property: "fill"
            to: 1
            duration: 700
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: win
            property: "rough"
            from: 1
            to: 0
            duration: 1500
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: win
            property: "t"
            to: 1
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: drain
        NumberAnimation {
            target: win
            property: "fill"
            to: 0
            duration: 260
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: win
            property: "t"
            to: 0
            duration: 260
            easing.type: Easing.InCubic
        }
    }

    function ripple(x, strength) {
        pool.ripple(x, strength);
    }
    function swell(x) {
        return pool.swell(x);
    }

    screen: Ui.screen
    visible: t > 0 || level > 0.001
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ekitai-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            drag = null;
            cursor = Math.max(0, activeId - 1);
            lister.running = true;
            keys.forceActiveFocus();
            drain.stop();
            flood.start();
            ripple(width * 0.3, 0.5);
            ripple(width * 0.75, 0.4);
        } else {
            flood.stop();
            drain.start();
        }
    }

    function close() {
        Ui.overview = false;
    }

    function go(id) {
        close();
        if (id !== activeId)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function focusWindow(c) {
        close();
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${c.address}" })`);
    }

    function moveWindow(c, id, at) {
        if (c.workspace.id === id)
            return;
        // move it in our copy straight away, so it doesn't jump back while hyprctl catches up
        clients = clients.map(o => o.address === c.address ? Object.assign({}, o, { workspace: { id: id } }) : o);
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${id}", window = "address:${c.address}", follow = false })`);
        refresh.restart();
        // the splash: a ring where it landed, and a ripple across the pool below
        const t = tiles.itemAt(ids.indexOf(id));
        if (t)
            t.splash(t.mapFromItem(win.contentItem, at.x, at.y));
        ripple(at.x, 0.7);
    }

    Process {
        id: lister
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                // floating windows above tiled ones, and the most recent on top within each
                win.clients = list.filter(c => c.mapped !== false && (c.workspace?.id ?? 0) > 0)
                    .sort((a, b) => (a.floating - b.floating) || (b.focusHistoryID - a.focusHistoryID));
            }
        }
    }

    // keep up with windows opening, closing and moving while it's open
    Timer {
        id: refresh
        interval: 150
        onTriggered: if (win.open && !win.drag)
            lister.running = true
    }
    Connections {
        target: Hyprland
        enabled: win.open
        function onRawEvent(e) {
            if (/^(openwindow|closewindow|movewindow|changefloatingmode|resizewindow)/.test(e.name))
                refresh.restart();
        }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void {
            Ui.overview = !Ui.overview;
        }
        function open(): void {
            Ui.overview = true;
        }
        function close(): void {
            Ui.overview = false;
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape)
                win.close();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                win.go(win.ids[win.cursor]);
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab)
                win.cursor = (win.cursor + 1) % win.count;
            else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab)
                win.cursor = (win.cursor - 1 + win.count) % win.count;
            else if (k === Qt.Key_Down || k === Qt.Key_J)
                win.cursor = Math.min(win.count - 1, win.cursor + win.cols);
            else if (k === Qt.Key_Up || k === Qt.Key_K)
                win.cursor = Math.max(0, win.cursor - win.cols);
            else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < win.count)
                win.go(k - Qt.Key_0);
            else if (k === Qt.Key_0 && win.count >= 10)
                win.go(10);
            else
                return;
            e.accepted = true;
        }
    }

    // ── the backdrop: blurred, dimmed wallpaper with the liquid flooding up over it ──
    Item {
        anchors.fill: parent
        opacity: win.t

        Pool {
            id: pool
            anchors.fill: parent
            level: win.level
            rough: win.rough
        }

        // a click on nothing closes; it also drops a ripple where you clicked
        MouseArea {
            anchors.fill: parent
            onClicked: m => {
                win.ripple(m.x, 0.6);
                win.close();
            }
        }
    }

    // ── the grid ──
    readonly property real gap: 18
    readonly property real tileW: {
        const byW = (width * 0.9 - gap * (cols - 1)) / cols;
        const byH = ((height * 0.8 - 40 - gap * (rows - 1)) / rows - 26) * (Ui.screen?.width ?? 16) / (Ui.screen?.height ?? 9);
        return Math.floor(Math.min(byW, byH, 420));
    }
    readonly property real tileH: Math.round(tileW * (Ui.screen?.height ?? 9) / (Ui.screen?.width ?? 16))

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: grid.top
        anchors.bottomMargin: 22
        opacity: win.t
        text: "workspaces"
        font.pixelSize: Style.big
        color: Colors.bright
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - win.t) * 40   // rises with the liquid
        columns: win.cols
        spacing: win.gap
        opacity: win.t

        Repeater {
            id: tiles
            model: win.ids

            Item {
                id: tile
                required property int modelData
                required property int index
                readonly property int wsId: modelData
                readonly property bool active: wsId === win.activeId
                readonly property bool selected: index === win.cursor
                readonly property bool target: win.drag !== null && win.dropId === wsId && win.drag.workspace.id !== wsId
                readonly property var mine: win.clients.filter(c => c.workspace.id === wsId)
                readonly property var mon: Hyprland.workspaces.values.find(w => w.id === wsId)?.monitor ?? Hyprland.focusedMonitor

                // its pool: deeper the more windows; it drops as one is lifted out and rises to meet one held over it
                readonly property int held: mine.length - (win.drag && win.drag.workspace.id === wsId ? 1 : 0) + (target ? 1 : 0)
                readonly property real fill: held ? Math.min(0.42, 0.1 + 0.08 * held) : 0

                // riding the big pool's surface: the bottom row bobs with it, the rows above a little less
                readonly property bool bottomRow: Math.floor(index / win.cols) === win.rows - 1
                readonly property real bob: win.visible ? win.swell(grid.x + x + width / 2) * (bottomRow ? 0.3 : 0.14) : 0
                transform: Translate {
                    y: tile.bob
                }

                width: win.tileW
                height: win.tileH + 26

                // the area the windows sit in, in layout pixels: the monitor, widened to take in any
                // windows scrolled off its sides
                readonly property rect box: {
                    const mx = mon?.x ?? 0, my = mon?.y ?? 0;
                    const mw = mon?.width ?? (Ui.screen?.width ?? 1), mh = mon?.height ?? (Ui.screen?.height ?? 1);
                    let x0 = mx, y0 = my, x1 = mx + mw, y1 = my + mh;
                    for (const c of mine) {
                        x0 = Math.min(x0, c.at[0]);
                        y0 = Math.min(y0, c.at[1]);
                        x1 = Math.max(x1, c.at[0] + c.size[0]);
                        y1 = Math.max(y1, c.at[1] + c.size[1]);
                    }
                    return Qt.rect(x0, y0, x1 - x0, y1 - y0);
                }
                readonly property real k: Math.min(screenBox.width / box.width, screenBox.height / box.height)

                // a ring spreading from where a window landed
                function splash(p) {
                    ring.x = p.x;
                    ring.y = p.y;
                    splashAnim.restart();
                }

                Frame {
                    id: screenBox
                    width: parent.width
                    height: win.tileH
                    color: Colors.bg1
                    border.width: tile.target || tile.selected ? 2 : Style.line
                    border.color: tile.target ? Colors.bright : tile.selected ? Colors.accent : tile.active ? Colors.mid : Colors.faint
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Style.fast
                        }
                    }

                    Item {
                        id: inner
                        anchors.fill: parent
                        anchors.margins: Look.round ? 3 : 2
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
                            sourceSize.width: win.tileW
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: tile.active || tile.selected ? 0.5 : 0.28
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Style.fast
                                }
                            }
                        }

                        Liquid {
                            anchors.fill: parent
                            level: tile.fill
                            alive: win.open && !Perf.low
                            ripple: 1.5
                            opacity: 0.5
                        }

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.4 - height / 2
                            visible: tile.mine.length === 0
                            text: tile.target ? "drop here" : "empty"
                            color: tile.target ? Colors.bright : Colors.dim
                        }

                        // the windows, to scale
                        Repeater {
                            model: tile.mine

                            Item {
                                id: thumb
                                required property var modelData
                                readonly property var c: modelData
                                readonly property var toplevel: Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === String(c.address).replace(/^0x/, "")) ?? null
                                readonly property bool lifted: win.drag?.address === c.address

                                x: (inner.width - tile.box.width * tile.k) / 2 + (c.at[0] - tile.box.x) * tile.k
                                y: (inner.height - tile.box.height * tile.k) / 2 + (c.at[1] - tile.box.y) * tile.k
                                width: Math.max(8, c.size[0] * tile.k)
                                height: Math.max(8, c.size[1] * tile.k)
                                opacity: lifted ? 0.2 : 1
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Style.fast
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Colors.bg2
                                    radius: Look.round ? 4 : 0
                                    border.width: Style.line
                                    border.color: area.containsMouse ? Colors.accent : Colors.faint
                                }
                                ScreencopyView {
                                    anchors.centerIn: parent
                                    visible: win.open && thumb.toplevel !== null
                                    captureSource: visible ? thumb.toplevel?.wayland ?? null : null
                                    live: !Perf.low
                                    constraintSize: Qt.size(thumb.width, thumb.height)
                                    width: implicitWidth
                                    height: implicitHeight
                                    layer.enabled: true  // see-through windows blend over the tile instead of punching through
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: !thumb.toplevel && thumb.width > 24
                                    implicitSize: Math.min(28, thumb.width / 2, thumb.height / 2)
                                    source: win.icon(thumb.c.class)
                                }
                                Rectangle {              // hover: an accent edge over the preview
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: Look.round ? 4 : 0
                                    visible: area.containsMouse && !win.drag
                                    border.width: 2
                                    border.color: Colors.accent
                                }

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: win.drag ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    preventStealing: true
                                    property point start
                                    property point last
                                    property real lastAt: 0
                                    onEntered: win.cursor = tile.index
                                    onPressed: m => {
                                        start = Qt.point(m.x, m.y);
                                        last = mapToItem(win.contentItem, m.x, m.y);
                                        lastAt = Date.now();
                                    }
                                    onPositionChanged: m => {
                                        if (!pressed)
                                            return;
                                        const p = mapToItem(win.contentItem, m.x, m.y);
                                        if (!win.drag && Math.hypot(m.x - start.x, m.y - start.y) > 6) {
                                            win.drag = thumb.c;
                                            win.vel = Qt.point(0, 0);
                                            ghost.w = thumb.width;
                                            ghost.h = thumb.height;
                                            ghost.grab = start;
                                            ghost.toplevel = thumb.toplevel;
                                        }
                                        if (win.drag) {
                                            const now = Date.now(), dt = Math.max(8, now - lastAt) / 1000;
                                            win.vel = Qt.point(win.vel.x * 0.6 + (p.x - last.x) / dt * 0.4, win.vel.y * 0.6 + (p.y - last.y) / dt * 0.4);
                                            win.dragAt = p;
                                            win.dropId = grid.idAt(p);
                                        }
                                        last = p;
                                        lastAt = Date.now();
                                    }
                                    onReleased: {
                                        if (!win.drag)
                                            return;
                                        const c = win.drag, id = win.dropId, at = win.dragAt;
                                        win.drag = null;
                                        win.dropId = -1;
                                        if (id > 0)
                                            win.moveWindow(c, id, at);
                                    }
                                    onCanceled: {
                                        win.drag = null;
                                        win.dropId = -1;
                                    }
                                    onClicked: if (!win.drag)
                                        win.focusWindow(thumb.c)
                                }
                            }
                        }

                        // the splash ring
                        Rectangle {
                            id: ring
                            property real r: 0
                            width: r * 2
                            height: r * 2
                            radius: r
                            transform: Translate {
                                x: -ring.r
                                y: -ring.r
                            }
                            color: "transparent"
                            border.width: 2
                            border.color: Colors.bright
                            opacity: 0
                            ParallelAnimation {
                                id: splashAnim
                                NumberAnimation {
                                    target: ring
                                    property: "r"
                                    from: 4
                                    to: win.tileW * 0.35
                                    duration: 650
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: ring
                                    property: "opacity"
                                    from: 0.9
                                    to: 0
                                    duration: 650
                                    easing.type: Easing.InQuad
                                }
                            }
                        }
                    }

                    // a click on the workspace itself (not a window) goes there
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.cursor = tile.index
                        onClicked: win.go(tile.wsId)
                    }
                }

                // label: the number, then a droplet per window
                Row {
                    anchors.top: screenBox.bottom
                    anchors.topMargin: 8
                    x: 2
                    spacing: 8
                    Frame {
                        pill: true
                        width: num.implicitWidth + 14
                        height: 18
                        color: tile.active ? Colors.accent : tile.selected ? Colors.bg3 : Colors.bg2
                        Txt {
                            id: num
                            anchors.centerIn: parent
                            text: tile.wsId
                            color: tile.active ? Colors.bg : tile.selected ? Colors.bright : Colors.mid
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: Math.min(8, tile.held)
                            Frame {
                                required property int index
                                pill: true
                                width: 7
                                height: 7
                                color: tile.target && index === tile.held - 1 ? Colors.bright : tile.selected ? Colors.accent : Colors.mid
                            }
                        }
                    }
                }
            }
        }

        // the workspace whose tile is under a point (in window coordinates), or -1
        function idAt(p) {
            for (let i = 0; i < tiles.count; i++) {
                const t = tiles.itemAt(i);
                if (!t)
                    continue;
                const q = t.mapFromItem(win.contentItem, p.x, p.y);
                if (q.x >= 0 && q.y >= 0 && q.x <= t.width && q.y <= t.height)
                    return t.wsId;
            }
            return -1;
        }
    }

    // the window being dragged: a glowing droplet under the pointer, stretched along its motion
    Item {
        id: ghost
        property real w: 0
        property real h: 0
        property point grab
        property var toplevel: null
        readonly property real speed: Math.hypot(win.vel.x, win.vel.y)
        readonly property real stretch: Math.min(0.3, speed / 6000)
        readonly property real angle: Math.atan2(win.vel.y, win.vel.x) * 180 / Math.PI
        visible: win.drag !== null
        x: win.dragAt.x - grab.x
        y: win.dragAt.y - grab.y
        width: w
        height: h
        z: 100
        transform: [
            Rotation {
                origin.x: ghost.w / 2
                origin.y: ghost.h / 2
                angle: -ghost.angle
            },
            Scale {
                origin.x: ghost.w / 2
                origin.y: ghost.h / 2
                xScale: 1.06 * (1 + ghost.stretch)
                yScale: 1.06 * (1 - ghost.stretch * 0.5)
            },
            Rotation {
                origin.x: ghost.w / 2
                origin.y: ghost.h / 2
                angle: ghost.angle
            }
        ]

        RectangularGlow {
            anchors.fill: parent
            glowRadius: 14
            spread: 0.1
            cornerRadius: Look.round ? 18 : 6
            color: Qt.alpha(Colors.accent, 0.45)
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: Colors.bg2
            radius: Look.round ? Math.min(12, ghost.w / 4) : 2
            border.width: 2
            border.color: Colors.bright
        }
        ScreencopyView {
            anchors.centerIn: parent
            captureSource: ghost.visible ? ghost.toplevel?.wayland ?? null : null
            live: false
            constraintSize: Qt.size(ghost.w, ghost.h)
            width: implicitWidth
            height: implicitHeight
            layer.enabled: true
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: grid.bottom
        anchors.topMargin: 26
        opacity: win.t
        text: "drag a window to move it   ·   click to focus   ·   arrows + enter or 1-9   ·   esc"
        font.pixelSize: Style.small
        color: Colors.bright
    }

    function icon(cls) {
        cls = cls || "";
        return Quickshell.iconPath(cls.toLowerCase(), true) || Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon ?? "", true) || Quickshell.iconPath("application-x-executable");
    }
}

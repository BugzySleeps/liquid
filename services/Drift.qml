pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The desktop widgets in the scrolling layout's endless row (Settings.canvasWidgets): so they don't sit stuck to
// the glass while the windows slide by, they move with the row too. "parallax": a far-off layer, drifting at a
// third of the windows' pace · "canvas": on the row itself, scrolling away with the windows · "pinned": still.
// While you're editing them they're back where they were placed, so dragging works as usual.
//
// Depth (Settings.depth): the widgets also float at different distances over the wallpaper. They lean away
// from the pointer, near ones more than far ones (props.depth: near / mid / far, or by size), casting shadows
// that shift with them, and sink back (smaller, dimmer) while windows are open on the workspace, coming
// forward again on an empty desktop. The wallpaper is the farthest layer of all: it leans a little from the
// pointer too, and slides a little while the infinite desktop pans (all the floating windows moving together,
// from ~/scripts/infinite_desktop_core.py) or the row scrolls, then drifts back to the middle once that stops,
// so every workspace's wallpaper rests in the same place (Wallpaper.qml zooms it in a touch so there's room).
// Paused in performance mode.
Singleton {
    id: root

    // ── depth ──
    readonly property bool depthOn: Settings.depth && !Widgets.editing && !Perf.low
    // where the pointer is, -1…1 across the focused screen: `tx`/`ty` as last read, `px`/`py` gliding after it
    // (every frame, see `glide`, so the 30-a-second readings never show as steps)
    property real tx: 0
    property real ty: 0
    property real px: 0
    property real py: 0
    // windows open on the workspace in front: 1, eased (the widgets sink back)
    readonly property bool crowded: (Hyprland.focusedWorkspace?.toplevels?.values?.length ?? 0) > 0
    property real crowd: depthOn && crowded ? 1 : 0
    Behavior on crowd {
        NumberAnimation {
            duration: 700
            easing.type: Easing.InOutCubic
        }
    }
    onDepthOnChanged: if (!depthOn) {
        tx = 0;
        ty = 0;
        panTX = panX = 0;
        panTY = panY = 0;
    }

    // everything that follows a reading glides to it frame by frame (an exponential ease: smooth however often
    // the readings come, and it never restarts), and stops once it's caught up
    readonly property bool settled: Math.abs(tx - px) < 0.0005 && Math.abs(ty - py) < 0.0005
        && Math.abs(panTX) < 0.05 && Math.abs(panTY) < 0.05 && Math.abs(panX) < 0.05 && Math.abs(panY) < 0.05
    FrameAnimation {
        id: glide
        running: !root.settled
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            const k = 1 - Math.exp(-dt * 7);     // the pointer: soft, a little behind
            const kp = 1 - Math.exp(-dt * 9);    // panning and scrolling: closer behind
            root.px += (root.tx - root.px) * k;
            root.py += (root.ty - root.py) * k;
            // the push from a pan or scroll fades (about a second and a half), so the wallpaper comes home
            const fade = Math.exp(-dt * 1.6);
            root.panTX *= fade;
            root.panTY *= fade;
            root.panX += (root.panTX - root.panX) * kp;
            root.panY += (root.panTY - root.panY) * kp;
        }
    }

    // ── the wallpaper ──
    // how far the infinite desktop has panned on this workspace, px (the floating windows' shared move)
    // the push the windows' last moves gave it, px (fading back to 0), and that glided
    property real panTX: 0
    property real panTY: 0
    property real panX: 0
    property real panY: 0
    property var last: ({})                      // floating window address → [x, y], at the last look
    property int lastWs: -1
    // where the wallpaper sits, px off centre: softly held inside `room` (Wallpaper.qml's zoom leaves that much)
    property real roomX: 0
    property real roomY: 0
    function soft(v, r) {
        return r > 0 ? r * Math.tanh(v / r) : 0;
    }
    readonly property real wallX: !depthOn ? 0 : soft(soft(panX * 0.08, roomX * 0.75) - px * 4, roomX)
    readonly property real wallY: !depthOn ? 0 : soft(soft(panY * 0.08, roomY * 0.75) - py * 3, roomY)

    // the windows, from Hyprland's socket: ~10 times a second while there are floating ones to watch pan, once a
    // second otherwise (to notice one); and on window events, for the row's scroll and what covers the screen
    property int floating: 0
    Timer {
        running: root.depthOn
        interval: root.floating > 0 ? 100 : 1000
        repeat: true
        onTriggered: root.readClients()
    }
    function readClients() {
        if (floaters.connected)
            floaters.again = true;               // one's on its way: look again once it's in (it may be stale)
        else
            floaters.connected = true;
    }
    Socket {
        id: floaters
        path: cursor.path
        onConnectionStateChanged: if (connected) {
            buf = "";
            write("j/clients");
            flush();
        }
        // read up to each "]" until the whole reply parses, then hang up ourselves (waiting for Hyprland to,
        // the socket logs a warning every time)
        property string buf: ""
        property bool again: false
        parser: SplitParser {
            splitMarker: "]"
            onRead: data => {
                floaters.buf += data + "]";
                let list;
                try {
                    list = JSON.parse(floaters.buf);
                } catch (e) {
                    return;                      // not all of it yet
                }
                floaters.connected = false;
                root.lookAtClients(list);
                if (floaters.again) {
                    floaters.again = false;
                    root.readClients();
                }
            }
        }
    }
    function lookAtClients(list) {
        const wsNow = Hyprland.focusedWorkspace?.id;
        const mon = Hyprland.focusedMonitor;
        const mx = mon?.lastIpcObject?.x ?? 0, my = mon?.lastIpcObject?.y ?? 0;
        const mine = list.filter(c => c.workspace?.id === wsNow && c.mapped !== false && !c.hidden);
        // the row's scroll: how far its leftmost column sits past where the row starts (a gap in from the edge)
        const xs = mine.filter(c => !c.floating && !c.fullscreen).map(c => c.at[0] - mx);
        const scrolled = xs.length ? Math.max(0, 18 - Math.min(...xs)) : 0;
        if (depthOn && !jump && wsNow === lastWs)  // the row moved on this workspace: a push the other way
            panTX -= scrolled - scroll;
        scroll = scrolled;
        jump = false;
        // is the wallpaper all but hidden? (sampled on a grid: windows overlap, and gaps between them count)
        if (mon && mine.length) {
            let hit = 0, n = 0;
            for (let gy = 0.5; gy < 12; gy++)
                for (let gx = 0.5; gx < 20; gx++) {
                    const x = mx + gx / 20 * mon.width, y = my + gy / 12 * mon.height;
                    n++;
                    if (mine.some(c => x >= c.at[0] && x < c.at[0] + c.size[0] && y >= c.at[1] && y < c.at[1] + c.size[1]))
                        hit++;
                }
            covered = hit / n > 0.97;
        } else {
            covered = false;
        }
        floating = mine.filter(c => c.floating).length;
        if (depthOn)
            lookAtFloaters(list);
    }
    // windows cover (almost) all of the screen: the wallpaper can rest (Wallpaper.qml)
    property bool covered: false

    function lookAtFloaters(list) {
        const ws = Hyprland.focusedWorkspace?.id ?? -1;
        if (ws !== lastWs) {                     // another workspace: nothing to compare yet, and no push carried over
            panTX = panX = 0;
            panTY = panY = 0;
            lastWs = ws;
            last = {};
        }
        const now = {};
        let dx = null, dy = null, same = true, moved = false;
        for (const c of list) {
            if (!c.floating || c.workspace?.id !== ws || c.pinned)
                continue;
            now[c.address] = c.at;
            const was = last[c.address];
            if (!was)
                continue;
            const ex = c.at[0] - was[0], ey = c.at[1] - was[1];
            if (dx === null) {
                dx = ex;
                dy = ey;
            } else if (Math.abs(ex - dx) > 2 || Math.abs(ey - dy) > 2) {
                same = false;                    // they didn't all move together: not a pan
            }
            if (ex !== 0 || ey !== 0)
                moved = true;
        }
        if (moved && same && dx !== null) {
            panTX += dx;
            panTY += dy;
        }
        last = now;
    }

    // how near a widget sits, 0.3 (far) … 1 (near): props.depth, or by its size (bigger ones nearer)
    function nearness(w) {
        const d = w.props?.depth ?? "auto";
        if (d === "near")
            return 1;
        if (d === "mid")
            return 0.6;
        if (d === "far")
            return 0.3;
        return Math.max(0.3, Math.min(1, Math.sqrt(w.w * w.h) / 320));
    }

    // the pointer, straight from Hyprland's socket (no process each time): asked ~30 times a second
    property int still: 0                        // readings in a row where the pointer hadn't moved
    Timer {
        running: root.depthOn
        interval: root.still > 6 ? 150 : 33      // 30 a second while it moves, ~7 once it's been still a moment
        repeat: true
        onTriggered: if (!cursor.connected)
            cursor.connected = true
    }
    Socket {
        id: cursor
        property string lastRaw: ""
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
        onConnectionStateChanged: if (connected) {
            write("j/cursorpos");
            flush();
        }
        parser: SplitParser {
            splitMarker: "}"
            onRead: data => {
                const x = /"x":\s*(-?\d+)/.exec(data), y = /"y":\s*(-?\d+)/.exec(data);
                const m = Hyprland.focusedMonitor;
                if (x && y && m) {
                    const sx = m.lastIpcObject?.x ?? 0, sy = m.lastIpcObject?.y ?? 0;
                    const raw = x[1] + "," + y[1];
                    root.still = raw === cursor.lastRaw ? root.still + 1 : 0;
                    cursor.lastRaw = raw;
                    root.tx = Math.max(-1, Math.min(1, ((+x[1] - sx) / m.width) * 2 - 1));
                    root.ty = Math.max(-1, Math.min(1, ((+y[1] - sy) / m.height) * 2 - 1));
                }
                cursor.connected = false;
            }
        }
    }

    readonly property real pace: Settings.canvasWidgets === "canvas" ? 1 : Settings.canvasWidgets === "parallax" ? 0.3 : 0

    // how far along its row the workspace in front has scrolled: how far its leftmost column sits past where the
    // row starts (a gap in from the screen's edge)
    property real scroll: 0
    property bool jump: false                    // a new workspace: there at once, no slide
    property real shift: Widgets.editing ? 0 : -scroll * pace
    Behavior on shift {
        enabled: !root.jump
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutQuint
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.jump = true;
            look.restart();
        }
        function onRawEvent(e) {
            if (/^(activewindow|movewindow|openwindow|closewindow|resizewindow|changefloatingmode|configreloaded|fullscreen)/.test(e.name))
                look.restart();
        }
    }
    Component.onCompleted: look.restart()

    Timer {
        id: look
        interval: 50
        onTriggered: root.readClients()
    }
    // a mode turned on: catch up
    onPaceChanged: look.restart()
}

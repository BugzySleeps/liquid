pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Widgets on two boards: the desktop's (per workspace) and the lock screen's (where they can float on
// the liquid). What's placed where, and edit mode (for one board at a time).
// Saved to ~/.local/state/ekitai/widgets.json (outside the config dir, so saving doesn't reload the shell).
//   qs -c ekitai ipc call widgets edit          toggle edit mode (SUPER+W)
//   qs -c ekitai ipc call lock edit             edit the lock screen's widgets (in the lock preview)
//   qs -c ekitai ipc call widgets add clock     add a widget in the middle of the screen
//   qs -c ekitai ipc call widgets note "text"   add a line to the scratchpad
Singleton {
    id: root

    // w/h: starting size · minW/minH: smallest it resizes to · single: only one allowed · props: its settings
    readonly property var types: ({
        clock: { title: "clock", icon: "󰥔", desc: "digital or analog", w: 272, h: 128, minW: 144, minH: 80, props: { style: "digital", seconds: true } },
        calendar: { title: "calendar", icon: "󰃭", desc: "this month, today filled in", w: 256, h: 240, minW: 208, minH: 208, props: {} },
        weather: { title: "weather", icon: "󰖐", desc: "now and the next 3 days", w: 272, h: 160, minW: 208, minH: 128, props: { city: "", units: "celsius", place: "sharing" } },
        fetch: { title: "fetch", icon: "󰆍", desc: "your system, terminal style", w: 384, h: 224, minW: 304, minH: 192, props: {} },
        media: { title: "now playing", icon: "󰝚", desc: "art, track and controls", w: 352, h: 160, minW: 288, minH: 128, single: true, props: {} },
        lyrics: { title: "lyrics", icon: "󰎈", desc: "synced lyrics (lrclib.net)", w: 464, h: 144, minW: 256, minH: 96, single: true, props: {} },
        bars: { title: "visualizer", icon: "󰺢", desc: "big cava bars", w: 368, h: 128, minW: 160, minH: 64, props: {} },
        note: { title: "note", icon: "󰎚", desc: "double-click to type", w: 224, h: 160, minW: 128, minH: 80, props: { text: "", size: 13, shared: true } },
        image: { title: "image", icon: "󰋩", desc: "any picture, tinted green", w: 240, h: 240, minW: 80, minH: 80, props: { path: "", tint: true } },
        claude: { title: "claude", icon: "✻", desc: "claude code token usage", w: 320, h: 224, minW: 256, minH: 192, props: {} }
    })
    readonly property var order: ["clock", "calendar", "weather", "fetch", "media", "lyrics", "bars", "note", "image", "claude"]

    component WidgetData: QtObject {
        property string uid
        property string type
        property string board: "desktop"   // "desktop" or "lock"
        property string screen
        property real x
        property real y
        property real w
        property real h
        property var workspaces: []     // empty = every workspace
        property var props: ({})
        property bool frame: true       // black box + green border, or just the content
    }

    property list<QtObject> items: []
    property bool editing: false

    // the scratchpad: the control centre's notes, and every note widget set to "scratchpad"
    property string scratch: ""
    function setScratch(t) {
        if (t === scratch)
            return;
        scratch = t;
        save();
    }
    property string board: "desktop"    // the board being edited

    function edit(b) {
        if (editing && board === b) {
            editing = false;
        } else {
            board = b;
            editing = true;
        }
    }
    property bool snap: true
    readonly property int grid: 16
    property string selected: ""        // widget whose settings are open (edit mode)
    property string typing: ""          // note being typed in

    // the right-click desktop menu
    property bool menuOpen: false
    property real menuX: 0
    property real menuY: 0
    property string menuScreen: ""
    property string menuBoard: "desktop"

    readonly property int workspace: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int workspaceCount: Math.max(5, workspace, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))

    onEditingChanged: {
        if (!editing)
            selected = "";
        menuOpen = false;
        typing = "";
    }

    function find(uid) {
        return items.find(i => i.uid === uid) ?? null;
    }

    function shownOn(w, wsId) {
        return w.workspaces.length === 0 || w.workspaces.includes(wsId);
    }

    function snapped(v) {
        return snap ? Math.round(v / grid) * grid : Math.round(v);
    }

    function add(type, screen, cx, cy, b) {
        const t = types[type];
        b = b ?? board;
        if (!t)
            return;
        const existing = t.single ? items.find(i => i.type === type && i.board === b) : null;
        if (existing) {
            board = b;
            editing = true;
            selected = existing.uid;
            return;
        }
        const w = maker.createObject(root, {
            uid: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            type,
            board: b,
            screen,
            x: snapped(Math.max(0, cx - t.w / 2)),
            y: snapped(Math.max(0, cy - t.h / 2)),
            w: t.w,
            h: t.h,
            workspaces: [],
            props: Object.assign({}, t.props, b === "lock" ? { float: true } : {})
        });
        items = [...items, w];
        menuOpen = false;
        board = b;
        editing = true;
        selected = w.uid;
        save();
    }

    function duplicate(uid) {
        const s = find(uid);
        if (!s || types[s.type].single)
            return;
        const w = maker.createObject(root, {
            uid: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            type: s.type,
            board: s.board,
            screen: s.screen,
            x: s.x + grid * 2,
            y: s.y + grid * 2,
            w: s.w,
            h: s.h,
            workspaces: s.workspaces.slice(),
            props: Object.assign({}, s.props),
            frame: s.frame
        });
        items = [...items, w];
        selected = w.uid;
        save();
    }

    function remove(uid) {
        const w = find(uid);
        if (!w)
            return;
        items = items.filter(i => i !== w);
        if (selected === uid)
            selected = "";
        w.destroy();
        save();
    }

    function setProp(w, key, value) {
        const p = Object.assign({}, w.props);
        p[key] = value;
        w.props = p;
        save();
    }

    // workspace chips: "all" clears the list; a number toggles that workspace
    function setAll(w) {
        w.workspaces = [];
        save();
    }

    function toggleWorkspace(w, id) {
        const has = w.workspaces.includes(id);
        w.workspaces = has ? w.workspaces.filter(x => x !== id) : [...w.workspaces, id].sort((a, b) => a - b);
        save();
    }

    function openMenu(b, screen, x, y) {
        menuBoard = b;
        menuScreen = screen;
        menuX = x;
        menuY = y;
        menuOpen = true;
    }

    // ── saving ─────────────────────────────────────────────
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/ekitai"
    property bool ready: false
    property bool restored: false

    Component {
        id: maker
        WidgetData {}
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: root.ready = true
    }

    FileView {
        id: file
        path: root.ready ? root.dir + "/widgets.json" : ""
        printErrors: false
        onLoaded: root.restore(text())
        onLoadFailed: root.restore("")
    }

    function restore(text) {
        if (restored)
            return;
        restored = true;
        let list = null, lockSeeded = false;
        try {
            const d = JSON.parse(text);
            list = d.widgets;
            root.scratch = d.scratch ?? "";
            lockSeeded = !!d.lockSeeded;
        } catch (e) {}
        if (!Array.isArray(list)) {
            // first run: a clock and a fetch box to start with
            const s = Quickshell.screens[0]?.name ?? "";
            list = [
                { type: "clock", screen: s, x: 48, y: 80, w: 272, h: 128 },
                { type: "fetch", screen: s, x: 48, y: 224, w: 384, h: 224 }
            ];
        }
        if (!lockSeeded) {
            // the lock screen starts with music floating on the left and the visualizer on the right
            const s = Quickshell.screens[0];
            list = [...list,
                { type: "media", board: "lock", screen: s?.name ?? "", x: 96, y: 0, w: 352, h: 144, props: { float: true } },
                { type: "bars", board: "lock", screen: s?.name ?? "", x: (s?.width ?? 1600) - 96 - 336, y: 0, w: 336, h: 112, props: { float: true } }];
        }
        items = list.filter(d => types[d.type]).map(d => maker.createObject(root, {
            uid: d.uid ?? Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            type: d.type,
            board: d.board ?? "desktop",
            screen: d.screen ?? "",
            x: d.x ?? 0,
            y: d.y ?? 0,
            w: d.w ?? types[d.type].w,
            h: d.h ?? types[d.type].h,
            workspaces: d.workspaces ?? [],
            props: Object.assign({}, types[d.type].props, d.props ?? {}),
            frame: d.frame ?? true
        }));
        save();
    }

    function save() {
        if (restored)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: file.setText(JSON.stringify({
            version: 2,
            lockSeeded: true,
            scratch: root.scratch,
            widgets: root.items.map(w => ({
                uid: w.uid,
                type: w.type,
                board: w.board,
                screen: w.screen,
                x: Math.round(w.x),
                y: Math.round(w.y),
                w: Math.round(w.w),
                h: Math.round(w.h),
                workspaces: w.workspaces,
                frame: w.frame,
                props: w.props
            }))
        }, null, 2) + "\n")
    }

    IpcHandler {
        target: "widgets"
        function edit(): void {
            root.edit("desktop");
        }
        // add a line to the scratchpad (control centre notes / scratchpad note widgets)
        function scratch(text: string): void {        // replace it ("" clears it)
            root.setScratch(text);
        }
        function note(text: string): void {
            root.setScratch(root.scratch ? root.scratch + "\n" + text : text);
        }
        //   qs -c ekitai ipc call widgets place lock lyrics 568 336 true
        // add a widget to a board ("desktop" or "lock") at x, y (its top-left), and return its id
        // (bare: without its box)
        function place(board: string, type: string, x: int, y: int, bare: bool): string {
            const s = Ui.screen, t = root.types[type];
            if (!t || (board !== "desktop" && board !== "lock"))
                return "";
            root.add(type, s?.name ?? "", x + t.w / 2, y + t.h / 2, board);
            const w = root.find(root.selected);
            if (w) {
                if (bare)
                    w.frame = false;
                if (board === "lock")
                    root.setProp(w, "float", false);   // placed at a spot: it stays there
                root.save();
            }
            root.editing = false;
            return root.selected;
        }
        // move a widget (its top-left)
        function move(uid: string, x: int, y: int): void {
            const w = root.find(uid);
            if (!w)
                return;
            w.x = x;
            w.y = y;
            root.save();
        }
        // change one setting of a widget, the value as JSON:  widgets setting <id> float false
        function setting(uid: string, key: string, json: string): void {
            const w = root.find(uid);
            if (!w)
                return;
            try {
                root.setProp(w, key, JSON.parse(json));
            } catch (e) {}
        }
        function add(type: string): void {
            const s = Ui.screen;
            root.add(type, s?.name ?? "", (s?.width ?? 1600) / 2, (s?.height ?? 900) / 2, "desktop");
        }
    }
}

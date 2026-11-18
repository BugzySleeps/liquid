import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// A terminal-style launcher:   液 ❯ fire_
//   type to filter apps · ↑/↓ or Tab to move · Enter to open · Esc to close
// The first character picks a mode (the chips under the prompt insert them):
//   =  maths             2^10 / 3           Enter copies the result
//   :  emoji             :smile             Enter types it into your window (and copies), Shift+Enter copies
//   /  files             /notes pdf         in your home folder; Enter opens, Shift+Enter shows it in its folder
//   !  web search        !g quickshell      !g !d !y !w !gh !r !aw !gw !gp; no bang searches DuckDuckGo
//   #  colours           #  or  #5fe878     pick off the screen, recent picks, the theme; Enter copies
//   >  run a command     >htop              Enter runs it, Shift+Enter runs it in a terminal
PanelWindow {
    id: win

    readonly property bool open: Ui.launcher
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
    exclusiveZone: 0
    anchors.top: true
    margins.top: Math.round((screen?.height ?? 900) * 0.16)
    implicitWidth: 560
    implicitHeight: frame.height + 4

    WlrLayershell.namespace: "ekitai-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            input.text = Ui.launcherText;
            Ui.launcherText = "";
            input.cursorPosition = input.text.length;
            list.currentIndex = 0;
            input.forceActiveFocus();
            colours.reload();
            history.reload();
        }
    }

    // ── modes ──────────────────────────────────────────────
    readonly property var modes: [
        { key: "=", name: "maths", glyph: "󰃬" },
        { key: ":", name: "emoji", glyph: "󰞅" },
        { key: "/", name: "files", glyph: "󰈞" },
        { key: "!", name: "web", glyph: "󰖟" },
        { key: "#", name: "colour", glyph: "󰏘" },
        { key: ">", name: "run", glyph: "" }
    ]
    readonly property string query: input.text.trim()
    readonly property string mode: modes.find(m => query.startsWith(m.key))?.name ?? "apps"
    readonly property string rest: mode === "apps" ? query : query.slice(1).trim()
    readonly property bool calc: mode === "maths"

    readonly property string calcResult: {
        if (!calc)
            return "";
        const expr = rest.replace(/\^/g, "**").replace(/x/g, "*");
        if (!/^[\d\s+\-*/().%]*$/.test(expr) || expr.trim() === "")
            return "";
        try {
            const v = Function('"use strict"; return (' + expr + ")")();
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    // Every mode gives rows of the same shape:
    //   { title, sub, icon (theme icon) | glyph (+ emoji: true) | swatch (colour),
    //     run (Enter), alt (Shift+Enter, optional), fill (put this in the prompt instead of running) }
    readonly property var rows: {
        switch (mode) {
        case "maths":
            return [];
        case "emoji":
            return emojiRows(rest.toLowerCase());
        case "files":
            return fileRows;
        case "web":
            return webRows(query.slice(1));
        case "colour":
            return colourRows(rest.toLowerCase());
        case "run":
            return runRows(rest);
        }
        return appRows(rest.toLowerCase());
    }

    function launch(i, shift) {
        if (calc) {
            if (calcResult)
                Quickshell.execDetached(["wl-copy", calcResult]);
            Ui.launcher = false;
            return;
        }
        const r = rows[i];
        if (!r)
            return;
        if (r.fill !== undefined) {              // e.g. a bang: complete it, keep typing
            input.text = r.fill;
            input.cursorPosition = input.text.length;
            return;
        }
        Ui.launcher = false;
        (shift && r.alt ? r.alt : r.run)();
    }

    function sh(script, ...args) {
        Quickshell.execDetached(["sh", "-c", script, "sh", ...args]);
    }

    // ── apps ───────────────────────────────────────────────
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    function score(app, q) {
        const name = app.name.toLowerCase();
        if (name.startsWith(q))
            return 4;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 3;
        if (name.includes(q))
            return 2;
        const extra = [app.genericName, app.comment, ...(app.keywords ?? [])].join(" ").toLowerCase();
        if (extra.includes(q))
            return 1;
        // letters in order: "ffx" -> firefox
        let i = 0;
        for (const c of name)
            if (c === q[i])
                i++;
        return i === q.length ? 0.5 : 0;
    }

    function appRow(a) {
        return {
            title: a.name,
            sub: (a.genericName || a.comment || "").toLowerCase(),
            icon: a.icon,
            run: () => a.runInTerminal ? Quickshell.execDetached(["kitty", "-e", ...a.command]) : a.execute()
        };
    }

    function appRows(q) {
        if (!q)
            return apps.map(appRow);
        return apps.map(a => ({ a, s: score(a, q) })).filter(r => r.s > 0).sort((x, y) => y.s - x.s).map(r => appRow(r.a));
    }

    // ── emoji (launcher/emoji.tsv, from github.com/github/gemoji, MIT) ──
    FileView {
        id: emojiFile
        path: Quickshell.shellDir + "/launcher/emoji.tsv"
        blockLoading: false
    }
    // [{ e, names: ["smile", …], desc, tags }]
    readonly property var emoji: emojiFile.text().split("\n").filter(l => l).map(l => {
        const [e, names, desc, tags] = l.split("\t");
        return { e, names: (names || "").split(" "), desc: desc || "", tags: tags || "" };
    })

    function emojiRow(m) {
        const say = e => {
            Quickshell.execDetached(["wl-copy", e]);
            sh("sleep 0.15; command -v wtype >/dev/null && wtype -- \"$1\"", e);
        };
        return {
            title: m.desc,
            sub: m.names.map(n => ":" + n + ":").join(" "),
            glyph: m.e,
            emoji: true,
            run: () => say(m.e),
            alt: () => Quickshell.execDetached(["wl-copy", m.e])
        };
    }

    function emojiRows(q) {
        if (!q)
            return emoji.slice(0, 60).map(emojiRow);
        const scored = [];
        for (const m of emoji) {
            let s = 0;
            if (m.names.some(n => n === q))
                s = 5;
            else if (m.names.some(n => n.startsWith(q)))
                s = 4;
            else if (m.desc.split(" ").some(w => w.startsWith(q)))
                s = 3;
            else if (m.tags.split(" ").some(w => w.startsWith(q)))
                s = 2;
            else if (m.names.some(n => n.includes(q)) || m.desc.includes(q))
                s = 1;
            if (s)
                scored.push({ m, s });
        }
        return scored.sort((a, b) => b.s - a.s).slice(0, 60).map(r => emojiRow(r.m));
    }

    // ── files: fd if it's installed, else find; skips hidden folders ──
    property var fileRows: []
    property string fileFor: ""                  // the query the current results are for
    readonly property string home: Quickshell.env("HOME")

    onRestChanged: if (mode === "files")
        fileTimer.restart()
    onModeChanged: {
        fileRows = [];
        fileFor = "";
        if (mode === "files")
            fileTimer.restart();
        if (mode === "run" && !bins.length && !binLister.running)
            binLister.running = true;
    }
    Timer {
        id: fileTimer
        interval: 160
        onTriggered: {
            if (win.rest.length < 2) {
                win.fileRows = [];
                win.fileFor = win.rest;
                return;
            }
            finder.running = false;
            finder.wanted = win.rest;
            // every word must appear in the path; the first one is what fd/find looks for
            finder.command = ["sh", "-c", `q="$1"; first=\${q%% *}
                if command -v fd >/dev/null; then fd -i --max-results 400 -- "$first" "$HOME"
                else find "$HOME" -mindepth 1 -maxdepth 7 -name '.*' -prune -o -iname "*$first*" -print 2>/dev/null | head -n 400; fi`, "sh", win.rest];
            finder.running = true;
        }
    }
    Process {
        id: finder
        property string wanted: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (finder.wanted !== win.rest)
                    return;                      // typed on since
                const words = finder.wanted.toLowerCase().split(/\s+/);
                const paths = text.split("\n").filter(p => p && words.every(w => p.toLowerCase().includes(w)));
                // names that start with the query first, then shorter paths
                const first = words[0];
                const base = p => p.replace(/\/$/, "").split("/").pop().toLowerCase();
                paths.sort((a, b) => (base(b).startsWith(first) - base(a).startsWith(first)) || a.length - b.length);
                win.fileRows = paths.slice(0, 40).map(p => win.fileRow(p.replace(/\/$/, "")));
                win.fileFor = finder.wanted;
            }
        }
    }

    function fileGlyph(p) {
        const ext = (p.split("/").pop().split(".").pop() || "").toLowerCase();
        const kinds = [
            [["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"], "󰋩"],
            [["flac", "mp3", "ogg", "opus", "wav", "m4a"], "󰎈"],
            [["mp4", "mkv", "webm", "mov", "avi"], "󰕧"],
            [["pdf"], "󰈦"],
            [["zip", "tar", "gz", "xz", "zst", "7z", "rar"], "󰗄"],
            [["qml", "js", "py", "sh", "lua", "rs", "c", "cpp", "h", "json", "toml", "css", "html"], "󰅩"],
            [["txt", "md", "conf", "log"], "󰈙"]
        ];
        return kinds.find(k => k[0].includes(ext))?.[1] ?? "󰈔";
    }

    function fileRow(p) {
        const name = p.split("/").pop();
        const dir = p.slice(0, p.length - name.length - 1).replace(home, "~") || "/";
        return {
            title: name,
            sub: dir,
            glyph: name.includes(".") ? fileGlyph(p) : "󰉋",
            run: () => Quickshell.execDetached(["xdg-open", p]),
            // the file manager, with the file selected (FileManager1); else just its folder
            alt: () => sh(`dbus-send --session --dest=org.freedesktop.FileManager1 --type=method_call /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:"file://$1" string:"" || xdg-open "$(dirname "$1")"`, p)
        };
    }

    // ── web search ─────────────────────────────────────────
    readonly property var bangs: [
        { bang: "d", name: "duckduckgo", url: "https://duckduckgo.com/?q=%s" },
        { bang: "g", name: "google", url: "https://www.google.com/search?q=%s" },
        { bang: "y", name: "youtube", url: "https://www.youtube.com/results?search_query=%s" },
        { bang: "w", name: "wikipedia", url: "https://en.wikipedia.org/w/index.php?search=%s" },
        { bang: "gh", name: "github", url: "https://github.com/search?q=%s" },
        { bang: "r", name: "reddit", url: "https://www.reddit.com/search/?q=%s" },
        { bang: "aw", name: "arch wiki", url: "https://wiki.archlinux.org/index.php?search=%s" },
        { bang: "gw", name: "gentoo wiki", url: "https://wiki.gentoo.org/index.php?search=%s" },
        { bang: "gp", name: "gentoo packages", url: "https://packages.gentoo.org/packages/search?q=%s" }
    ]

    function webRows(s) {
        // "!g foo" → google; "!g" alone (no space yet) → the bangs it could be; "!foo" → duckduckgo
        const m = s.match(/^(\S*)(\s+(.*))?$/) ?? ["", "", "", ""];
        const word = m[1].toLowerCase(), terms = (m[3] ?? "").trim();
        const named = bangs.find(b => b.bang === word);
        const search = (b, q) => ({
            title: q ? q : b.name,
            sub: q ? "search " + b.name + "   !" + b.bang : "!" + b.bang,
            glyph: "󰖟",
            run: () => Quickshell.execDetached(["xdg-open", b.url.replace("%s", encodeURIComponent(q))])
        });
        if (named && m[2] !== undefined) {       // a bang and a space: search with it, others below
            if (!terms)
                return [Object.assign(search(named, ""), { title: "search " + named.name + "…", run: () => {} })];
            return [search(named, terms), ...bangs.filter(b => b !== named).map(b => search(b, terms))];
        }
        if (!m[2]) {                             // still typing the first word
            const could = bangs.filter(b => b.bang.startsWith(word));
            const offer = could.map(b => ({
                title: "!" + b.bang,
                sub: b.name,
                glyph: "󰁔",
                fill: "!" + b.bang + " "
            }));
            return word ? [search(bangs[0], word), ...offer] : offer;
        }
        const q = s.trim();                      // not a bang: all of it is the search
        return bangs.map(b => search(b, q));
    }

    // ── colours ────────────────────────────────────────────
    FileView {
        id: colours
        path: (Quickshell.env("XDG_STATE_HOME") || win.home + "/.local/state") + "/rice/colours"
        printErrors: false
    }
    readonly property var recent: (colours.text() || "").split("\n").filter(c => /^#[0-9a-f]{6}$/.test(c))

    function hex(c) {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    function colourRow(c, title, sub) {
        const x = hex(c);
        return { title: title ?? x, sub: sub ?? "", swatch: c, run: () => Quickshell.execDetached(["wl-copy", x]) };
    }

    function colourRows(q) {
        const m = q.match(/^#?([0-9a-f]{3}|[0-9a-f]{6})$/);
        if (m) {                                 // a colour typed in: it in every format
            const six = m[1].length === 3 ? m[1].split("").map(d => d + d).join("") : m[1];
            const c = Qt.color("#" + six);
            const rgb = `rgb(${Math.round(c.r * 255)}, ${Math.round(c.g * 255)}, ${Math.round(c.b * 255)})`;
            const hsl = `hsl(${Math.round(Math.max(0, c.hslHue) * 360)}, ${Math.round(c.hslSaturation * 100)}%, ${Math.round(c.hslLightness * 100)}%)`;
            return [["#" + six, "hex"], [rgb, "rgb"], [hsl, "hsl"]].map(([v, kind]) => ({
                title: v,
                sub: kind + "   enter copies",
                swatch: c,
                run: () => Quickshell.execDetached(["wl-copy", v])
            }));
        }
        const pick = {
            title: "pick from the screen",
            sub: "click anywhere; the colour is copied and remembered",
            glyph: "󰈊",
            run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rice/pick-colour"])
        };
        const theme = Colors.keys.map(k => colourRow(Colors[k], hex(Colors[k]), "theme · " + k));
        const picked = recent.map(c => colourRow(Qt.color(c), c, "picked"));
        const all = [...picked, ...theme].filter(r => !q || (r.title + " " + r.sub).includes(q));
        return q ? all : [pick, ...all];
    }

    // ── run a command ──────────────────────────────────────
    FileView {
        id: history
        path: (Quickshell.env("XDG_STATE_HOME") || win.home + "/.local/state") + "/rice/run-history"
        printErrors: false
    }
    readonly property var ran: [...new Set((history.text() || "").split("\n").filter(l => l.trim()).reverse())]

    // everything on $PATH, read once when run mode is first used
    property var bins: []
    Process {
        id: binLister
        command: ["sh", "-c", "IFS=:; for d in $PATH; do ls -1 \"$d\" 2>/dev/null; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: win.bins = text.split("\n").filter(b => b)
        }
    }

    function remember(cmd) {
        sh(`f="$1"; mkdir -p "$(dirname "$f")"; printf '%s\\n' "$2" >> "$f"; tail -n 200 "$f" > "$f.tmp" && mv "$f.tmp" "$f"`, history.path, cmd);
    }

    function runRow(cmd, sub) {
        return {
            title: cmd,
            sub: sub,
            glyph: "",
            run: () => {
                remember(cmd);
                sh(`cd; exec sh -c "$1"`, cmd);
            },
            alt: () => {
                remember(cmd);
                Quickshell.execDetached(["kitty", "--hold", "sh", "-c", cmd]);
            }
        };
    }

    function runRows(cmd) {
        if (!cmd)
            return ran.slice(0, 30).map(c => runRow(c, "from history"));
        const rows = [runRow(cmd, "enter runs it   ·   shift+enter in a terminal")];
        for (const c of ran)
            if (c !== cmd && c.includes(cmd))
                rows.push(runRow(c, "from history"));
        if (!cmd.includes(" "))                  // still on the program's name: complete it from $PATH
            for (const b of bins)
                if (b !== cmd && b.startsWith(cmd) && rows.length < 40)
                    rows.push(Object.assign(runRow(b, "on your path"), { fill: ">" + b + " " }));
        return rows;
    }

    // ── look ───────────────────────────────────────────────
    Frame {
        id: frame
        y: (1 - win.t) * -12
        width: parent.width
        height: column.implicitHeight + 2
        opacity: win.t
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2

            // prompt
            RowLayout {
                width: parent.width
                height: 44
                spacing: 0
                Rectangle {
                    Layout.preferredWidth: Look.round ? 36 : 44
                    Layout.preferredHeight: Look.round ? 36 : 44
                    Layout.leftMargin: Look.round ? 4 : 0
                    radius: Look.round ? 18 : 0
                    color: Colors.accent
                    Text {
                        anchors.centerIn: parent
                        text: "液"
                        font.family: Style.cjk
                        font.pixelSize: 20
                        color: Colors.bg
                    }
                }
                Txt {
                    Layout.leftMargin: 12
                    text: "❯"
                    font.pixelSize: Style.px(16)
                    font.bold: true
                    color: Colors.bright
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 10
                    TextInput {
                        id: input
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colors.bright
                        selectionColor: Colors.accent
                        selectedTextColor: Colors.bg
                        font.family: Style.font
                        font.pixelSize: Style.px(15)
                        cursorDelegate: Rectangle {
                            width: 8
                            color: Colors.accent
                            visible: input.cursorVisible
                        }
                        onTextChanged: list.currentIndex = 0
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Escape) {
                                Ui.launcher = false;
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                win.launch(list.currentIndex, e.modifiers & Qt.ShiftModifier);
                            } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (e.key === Qt.Key_J && e.modifiers & Qt.ControlModifier)) {
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_K && e.modifiers & Qt.ControlModifier)) {
                                list.currentIndex = Math.max(0, list.currentIndex - 1);
                            } else {
                                return;
                            }
                            e.accepted = true;
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "search apps"
                        color: Colors.dim
                        font.pixelSize: Style.px(13)
                    }
                }
                Txt {
                    Layout.rightMargin: 14
                    text: win.mode === "apps" ? win.rows.length + "/" + win.apps.length : win.mode === "maths" ? "" : win.rows.length
                    color: Colors.mid
                    font.pixelSize: Style.small
                }
            }

            // the modes, as chips: click one to start it; the one you're in lights up
            Item {
                width: parent.width
                height: 34
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: win.modes
                        Frame {
                            id: chip
                            required property var modelData
                            readonly property bool on: win.mode === modelData.name
                            pill: true
                            width: chipRow.implicitWidth + 16
                            height: 22
                            color: on ? Colors.accent : chipArea.containsMouse ? Colors.bg3 : Colors.bg2
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Txt {
                                    text: chip.modelData.key
                                    color: chip.on ? Colors.bg : Colors.bright
                                }
                                Txt {
                                    text: chip.modelData.name
                                    color: chip.on ? Colors.bg : Colors.mid
                                }
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    input.text = chip.on ? "" : chip.modelData.key;
                                    input.cursorPosition = input.text.length;
                                    input.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // calculator result
            Item {
                visible: win.calc
                width: parent.width
                height: 64
                Txt {
                    anchors.centerIn: parent
                    text: win.calcResult ? "= " + win.calcResult : "…"
                    font.pixelSize: Style.px(24)
                    font.bold: true
                    color: Colors.bright
                }
                Txt {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.calcResult !== ""
                    text: "enter to copy"
                    font.pixelSize: Style.small
                    color: Colors.mid
                }
            }

            // nothing to show: say why
            Txt {
                visible: !win.calc && list.count === 0
                width: parent.width
                height: 48
                horizontalAlignment: Text.AlignHCenter
                color: Colors.dim
                text: win.mode === "files" ? (win.rest.length < 2 ? "type a file name" : finder.running || win.fileFor !== win.rest ? "searching…" : "no files match") : win.mode === "run" ? "type a command" : win.mode === "web" ? "type a search, or a bang like !g" : "nothing matches"
            }

            // results
            ListView {
                id: list
                visible: !win.calc
                width: parent.width
                height: Math.min(count, 8) * 40
                clip: true
                model: win.rows
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Style.fast
                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Look.round ? 6 : 0
                        anchors.rightMargin: Look.round ? 6 : 0
                        radius: Look.round ? 10 : 0
                        color: Colors.accent
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: list.width
                    height: 40

                    // the picture: an app icon (tinted), a glyph or emoji, or a colour swatch
                    Item {
                        id: pic
                        x: 14
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            anchors.fill: parent
                            implicitSize: 22             // else an SVG icon loads at its own (sometimes huge) size
                            visible: row.modelData.icon !== undefined
                            source: visible ? Quickshell.iconPath(row.modelData.icon, true) || Quickshell.iconPath("application-x-executable") : ""
                            // every icon recoloured into the one green (black when its row is selected)
                            layer.enabled: visible
                            layer.effect: Colorize {
                                hue: Math.max(0, Colors.accent.hslHue)
                                saturation: Colors.accent.hslSaturation < 0.05 ? 0 : 0.7   // a grey theme has no hue: grey, not red
                                lightness: row.current ? -1 : -0.05
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.modelData.glyph !== undefined
                            text: row.modelData.glyph ?? ""
                            font.family: row.modelData.emoji ? "Noto Color Emoji" : Style.icons
                            font.pixelSize: row.modelData.emoji ? 20 : 18
                            color: row.current ? Colors.bg : Colors.accent
                        }
                        Frame {
                            anchors.fill: parent
                            visible: row.modelData.swatch !== undefined
                            blob: true
                            color: row.modelData.swatch ?? "transparent"
                            border.width: 1
                            border.color: row.current ? Colors.bg : Colors.faint
                        }
                    }

                    Column {
                        anchors.left: pic.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            width: parent.width
                            text: row.modelData.title
                            font.pixelSize: Style.px(12)
                            color: row.current ? Colors.bg : Colors.bright
                        }
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.sub ?? ""
                            font.pixelSize: Style.small
                            color: row.current ? Colors.bg2 : Colors.mid
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: m => win.launch(row.index, m.modifiers & Qt.ShiftModifier)
                    }
                }
            }

            // footer: the keys for this mode
            Item {
                width: parent.width
                height: 4
            }
            Txt {
                width: parent.width
                height: 24
                horizontalAlignment: Text.AlignHCenter
                text: ({
                        apps: "↑↓ move   ⏎ open   esc close",
                        maths: "⏎ copy the result   esc close",
                        emoji: "⏎ type it   ⇧⏎ copy   esc close",
                        files: "⏎ open   ⇧⏎ show in folder   esc close",
                        web: "⏎ search   !g google  !y youtube  !gw gentoo wiki …",
                        colour: "⏎ copy   type a hex for rgb / hsl",
                        run: "⏎ run   ⇧⏎ in a terminal   esc close"
                    })[win.mode]
                font.pixelSize: Style.small
                color: Colors.dim
            }
        }
    }
}

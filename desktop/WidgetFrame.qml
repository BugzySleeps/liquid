import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.components
import qs.desktop.widgets
import "../components/Shapes.js" as Shapes

// One widget on a board: its box, its content, and (in edit mode) dragging and resizing.
// Desktop widgets not meant for this workspace fade out (faintly visible in edit mode, so you can
// still move them). Lock screen widgets set to float ride the liquid: their height comes from the
// surface under their middle, and they tilt with it; you only drag them sideways.
// In round and squiggle a widget can take a shape (props.shape: a cookie, a clover, an arch…, see
// components/Shapes.js), morphing into it, with its content inside; an image fills the shape. props.angle tilts it
// (degrees; not box or pill) and props.spin turns it; either way the content inside stays upright.
Item {
    id: frame

    required property var modelData
    readonly property var w: modelData
    readonly property var t: Widgets.types[w.type]
    // music, lyrics and visualizer widgets can step aside while nothing plays (only if Settings.hideIdleMusic)
    readonly property bool idle: Settings.hideIdleMusic && ["media", "lyrics", "bars"].includes(w.type) && !Media.player?.trackTitle
    readonly property bool here: (w.board === "lock" || Widgets.shownOn(w, Widgets.workspace)) && !idle
    property bool editing: false
    property var surface: null                   // x → the liquid's height there
    readonly property bool floating: !!surface && !!w.props.float
    readonly property bool selected: editing && Widgets.selected === w.uid
    readonly property string shape: Look.round ? (w.props.shape ?? "box") : "box"
    readonly property bool shaped: shape !== "box" || outline.t < 1    // (still morphing back to the box)
    readonly property bool fills: shaped && w.type === "image"
    // how much of the box (or glass) behind the content shows, 0..1 (props.bg). While editing, the others
    // keep a faint outline so you can still find them; the one you're tuning shows as it is.
    readonly property real bg: w.props.bg ?? 1
    readonly property real bgShown: editing && !selected ? Math.max(bg, 0.3) : bg
    // an analog clock's round face fills the biggest circle in the shape, not its biggest box
    readonly property bool roundFace: shaped && w.type === "clock" && w.props.style === "analog"

    // opened: a calendar's day card swells into the whole month (not saved: only while you look at it). It grows
    // out from its middle, nudged to stay on the screen, springing like the island, and closes by itself once the
    // pointer has been away a few seconds.
    property bool opened: false
    onEditingChanged: opened = false
    onOpenedChanged: squash.restart()
    // a squash and stretch as it opens or closes, like something soft being poked; and its depth (below)
    transform: [
        Translate {
            x: frame.leanX
            y: frame.leanY
        },
        Scale {
            origin.x: frame.width / 2
            origin.y: frame.height / 2
            xScale: frame.depthScale
            yScale: frame.depthScale
        },
        Scale {
            id: poke
            origin.x: frame.width / 2
            origin.y: frame.height / 2
        }
    ]
    SequentialAnimation {
        id: squash
        ParallelAnimation {
            NumberAnimation {
                target: poke
                property: "xScale"
                to: 1.06
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: poke
                property: "yScale"
                to: 0.9
                duration: 90
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: poke
                property: "xScale"
                to: 1
                duration: 520
                easing.type: Easing.OutElastic
                easing.amplitude: 1.1
                easing.period: 0.45
            }
            NumberAnimation {
                target: poke
                property: "yScale"
                to: 1
                duration: 520
                easing.type: Easing.OutElastic
                easing.amplitude: 1.1
                easing.period: 0.45
            }
        }
    }
    readonly property size openSize: Qt.size(Math.max(w.w, 256), Math.max(w.h, 252))
    property real grow: opened ? 1 : 0
    Behavior on grow {
        SpringAnimation {
            spring: 3.2
            damping: 0.3
            epsilon: 0.002
        }
    }
    readonly property real shownW: w.w + (openSize.width - w.w) * grow
    readonly property real shownH: w.h + (openSize.height - w.h) * grow
    // how far left / up it moves to grow round its middle and stay on screen
    readonly property real shiftX: !parent ? 0 : w.x - Math.max(0, Math.min(parent.width - shownW, w.x + (w.w - shownW) / 2))
    readonly property real shiftY: !parent ? 0 : w.y - Math.max(0, Math.min(parent.height - shownH, w.y + (w.h - shownH) / 2))
    HoverHandler {
        id: openHover
        enabled: frame.opened
    }
    Timer {
        running: frame.opened && !openHover.hovered
        interval: 3500
        onTriggered: frame.opened = false
    }

    // the desktop's move with the row of windows as it scrolls (Drift)
    x: w.x - shiftX + (w.board === "desktop" ? Drift.shift : 0)
    // floating: a quarter of it under the surface
    y: floating ? surface(w.x + w.w / 2) - w.h * 0.75 : w.y - shiftY
    rotation: floating ? Math.atan((surface(w.x + w.w / 2 + 80) - surface(w.x + w.w / 2 - 80)) / 160) * 180 / Math.PI * 0.6 : 0
    width: shownW
    height: shownH
    z: selected || grow > 0.01 ? 3 : 1
    Behavior on x {
        enabled: Widgets.gliding
        NumberAnimation { duration: 750; easing.type: Easing.InOutCubic }
    }
    Behavior on y {
        enabled: Widgets.gliding
        NumberAnimation { duration: 750; easing.type: Easing.InOutCubic }
    }
    Behavior on width {
        enabled: Widgets.gliding
        NumberAnimation { duration: 750; easing.type: Easing.InOutCubic }
    }
    Behavior on height {
        enabled: Widgets.gliding
        NumberAnimation { duration: 750; easing.type: Easing.InOutCubic }
    }

    // depth (Drift): a desktop widget leans away from the pointer, nearer ones further, and sinks back (smaller,
    // dimmer, its shadow closer in) while windows are open; far ones sink further
    readonly property bool deep: w.board === "desktop" && Drift.depthOn
    readonly property real near: deep ? Drift.nearness(w) : 0
    readonly property real leanX: deep ? -Drift.px * 16 * near : 0
    readonly property real leanY: deep ? -Drift.py * 10 * near : 0
    readonly property real depthScale: deep ? 1 - 0.07 * Drift.crowd * (1.3 - near) : 1
    readonly property real depthFade: deep ? 1 - 0.28 * Drift.crowd * (1.2 - near) : 1

    property real shown: here ? 1 : editing ? 0.3 : 0
    Behavior on shown {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }
    opacity: shown * depthFade
    visible: shown > 0
    scale: here || editing ? 1 : 0.95
    Behavior on scale {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }

    // its shadow on the wallpaper: softer and further the nearer it floats, sliding the other way to its lean,
    // drawn in close while it's sunk back (round for a shape: near enough for every one)
    RectangularShadow {
        anchors.fill: parent
        visible: frame.deep && frame.bgShown > 0.05 && (frame.w.frame || frame.shaped) && !frame.fills
        z: -1
        radius: frame.shaped ? Math.min(width, height) / 2.4 : Look.r(width, height)
        offset.x: -frame.leanX * 0.8
        offset.y: (6 + 12 * frame.near) * (1 - 0.5 * Drift.crowd) - frame.leanY * 0.8
        blur: (14 + 26 * frame.near) * (1 - 0.4 * Drift.crowd)
        spread: -4
        color: Qt.rgba(0, 0, 0, (0.28 + 0.22 * frame.near) * frame.bgShown)
    }

    // the box, or its shape
    Frame {
        anchors.fill: parent
        visible: !frame.shaped
        opacity: frame.bgShown
        color: frame.w.frame ? Colors.glass : "transparent"
        border.width: frame.w.frame || frame.editing ? Style.line : 0
        border.color: frame.selected ? Colors.accent : Colors.faint
    }
    ShapeOutline {
        id: outline
        anchors.fill: parent
        visible: frame.shaped
        opacity: frame.fills ? 1 : frame.bgShown  // a picture filling the shape is content, not background
        shape: frame.shape
        turn: frame.turn
        angle: frame.tilt
        angleShown: frame.tiltShown
        // the box inside for the content: the biggest that fits, with room for all of it or its compact layout
        need: Widgets.need(frame.w.type)
        least: Widgets.least(frame.w.type)
        pad: 6
        color: frame.w.frame && !frame.fills ? Colors.glass : "transparent"
        borderWidth: frame.w.frame || frame.editing ? Style.line : 0
        borderColor: frame.selected ? Colors.accent : Colors.faint
        fillItem: frame.fills ? picture : null
        screenAt: Qt.point(frame.x, frame.y)    // (the desktop covers the screen)
    }
    ShaderEffectSource {                         // an image, to fill the shape with
        id: picture
        width: frame.width
        height: frame.height
        sourceItem: frame.fills ? content : null
        hideSource: true
        visible: false
    }

    property real turn: 0
    // the tilt, 0–1 of a turn (box and pill are worked out for their own size, so they stay straight)
    readonly property real tilt: Shapes.free(shape) ? 0 : (w.props.angle ?? 0) / 360
    property real tiltShown: tilt
    Behavior on tiltShown {
        NumberAnimation {
            duration: Style.med
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation on turn {
        running: !!frame.w.props.spin && frame.shaped && frame.here && !Perf.low
        from: 0
        to: 1
        duration: 40000
        loops: Animation.Infinite
    }

    // a title sitting on the top border, like a terminal box:  ┌─ clock ───
    Rectangle {
        visible: frame.w.frame && !frame.editing && !frame.shaped
        x: Look.round ? 18 : 12
        y: -6
        width: title.implicitWidth + 10
        height: 12
        color: Colors.bg
        Txt {
            id: title
            anchors.centerIn: parent
            text: frame.t.title
            font.pixelSize: Style.small
            font.letterSpacing: 1
            color: Colors.mid
        }
    }

    Loader {
        id: content
        anchors.fill: parent
        // in a shape: the biggest box that fits inside it, or for a round face the biggest circle (an image: all
        // of it, cut to the shape)
        readonly property real pad: frame.w.frame ? 14 : 4
        readonly property real face: Math.max(0, outline.reach - 4)
        anchors.leftMargin: frame.fills ? 0 : frame.shaped ? (frame.roundFace ? frame.width / 2 - face : (1 - outline.inner[0]) * frame.width / 2 + 6) : pad
        anchors.rightMargin: anchors.leftMargin
        anchors.topMargin: frame.fills ? 0 : frame.shaped ? (frame.roundFace ? frame.height / 2 - face : (1 - outline.inner[1]) * frame.height / 2 + 6) : pad
        anchors.bottomMargin: anchors.topMargin
        sourceComponent: ({
                clock: clockW,
                calendar: calendarW,
                weather: weatherW,
                fetch: fetchW,
                media: mediaW,
                lyrics: lyricsW,
                bars: barsW,
                note: noteW,
                image: imageW,
                claude: claudeW
            })[frame.w.type] ?? null
    }

    Component {
        id: clockW
        ClockW {
            wd: frame.w
        }
    }
    Component {
        id: calendarW
        CalendarW {
            wd: frame.w
            open: frame.opened
            onToggle: frame.opened = !frame.opened
        }
    }
    Component {
        id: weatherW
        WeatherW {
            wd: frame.w
        }
    }
    Component {
        id: fetchW
        FetchW {
            wd: frame.w
        }
    }
    Component {
        id: mediaW
        MediaW {
            wd: frame.w
        }
    }
    Component {
        id: lyricsW
        LyricsW {
            wd: frame.w
        }
    }
    Component {
        id: barsW
        BarsW {
            wd: frame.w
        }
    }
    Component {
        id: noteW
        NoteW {
            wd: frame.w
        }
    }
    Component {
        id: imageW
        ImageW {
            wd: frame.w
        }
    }
    Component {
        id: claudeW
        ClaudeW {
            wd: frame.w
        }
    }

    // ── edit mode ──────────────────────────────────────────

    // drag anywhere on the widget to move it (snaps to the grid)
    MouseArea {
        anchors.fill: parent
        enabled: frame.editing
        hoverEnabled: true
        // a switched-off MouseArea still sets its cursor: only show the hand in edit mode, when it drags
        cursorShape: !enabled ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point grab
        onPressed: e => {
            grab = Qt.point(e.x, e.y);
            Widgets.selected = frame.w.uid;
            Widgets.menuOpen = false;
        }
        onPositionChanged: e => {
            if (!pressed)
                return;
            const p = mapToItem(frame.parent, e.x, e.y);
            frame.w.x = Math.max(0, Math.min(frame.parent.width - frame.w.w, Widgets.snapped(p.x - grab.x)));
            if (!frame.floating)                 // a floating one's height is the liquid's
                frame.w.y = Math.max(0, Math.min(frame.parent.height - frame.w.h, Widgets.snapped(p.y - grab.y)));
        }
        onReleased: Widgets.save()
    }

    // a tab above the widget: what it is and where it shows
    Rectangle {
        visible: frame.editing
        y: -20
        height: 18
        width: tabText.implicitWidth + 14
        color: frame.selected ? Colors.bright : Colors.accent
        Txt {
            id: tabText
            anchors.centerIn: parent
            text: frame.t.icon + " " + frame.t.title + "  ·  " + (frame.w.board === "lock" ? (frame.floating ? "floating" : "fixed") : frame.w.workspaces.length ? "ws " + frame.w.workspaces.join(" ") : "all")
            font.pixelSize: Style.small
            font.bold: true
            color: Colors.bg
        }
    }

    // delete
    Rectangle {
        visible: frame.editing
        anchors.right: parent.right
        y: -20
        width: 18
        height: 18
        color: delArea.containsMouse ? Colors.bright : Colors.accent
        Icon {
            anchors.centerIn: parent
            text: "󰅖"
            font.pixelSize: 12
            color: Colors.bg
        }
        MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Widgets.remove(frame.w.uid)
        }
    }

    // resize from the bottom-right corner
    Rectangle {
        visible: frame.editing
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 14
        height: 14
        color: sizeArea.pressed || sizeArea.containsMouse ? Colors.bright : Colors.accent
        MouseArea {
            id: sizeArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: Widgets.selected = frame.w.uid
            onPositionChanged: e => {
                if (!pressed)
                    return;
                const p = mapToItem(frame, e.x, e.y);
                // (in a shape it grows till the content fits inside)
                const size = Widgets.shapeSize(frame.w.type, frame.shape, Widgets.snapped(p.x), Widgets.snapped(p.y), frame.w.props.angle);
                frame.w.w = Math.min(frame.parent.width - frame.w.x, size[0]);
                frame.w.h = Math.min(frame.parent.height - frame.w.y, size[1]);
            }
            onReleased: Widgets.save()
        }
    }
}

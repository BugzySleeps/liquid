import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Digital: big HH:MM, a 60-segment seconds strip, the date.
// Analog: a square face (this rice has no circles) with tick marks and three hands.
Item {
    id: root
    property var wd

    readonly property bool analog: wd?.props.style === "analog"
    // in a widget shape (round / squiggle): a round face instead of the square one
    readonly property bool round: Look.round && (wd?.props.shape ?? "box") !== "box"
    onRoundChanged: face.requestPaint()
    readonly property bool seconds: wd?.props.seconds ?? true

    SystemClock {
        id: clock
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ── digital ──────────────────────────────────
    Column {
        visible: !root.analog
        anchors.centerIn: parent
        width: parent.width
        spacing: Math.max(4, root.height * 0.05)

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Style.px(Math.min(root.height * 0.5, root.width * 0.3))
            font.bold: true
            color: Colors.bright
        }
        // seconds: a strip of 60 cells filling left to right
        Row {
            visible: root.seconds
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1
            readonly property real cell: Math.max(1, (root.width * 0.86 - 59) / 60)
            Repeater {
                model: 60
                Rectangle {
                    required property int index
                    width: parent.cell
                    height: 4
                    color: index <= clock.seconds ? Colors.accent : Colors.faint
                }
            }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd · d MMMM").toLowerCase()
            font.pixelSize: Style.px(Math.max(Style.small, Math.min(14, root.height * 0.1)))
            color: Colors.mid
        }
    }

    // ── analog ───────────────────────────────────
    Canvas {
        id: face
        visible: root.analog
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        renderStrategy: Canvas.Cooperative

        Connections {
            target: clock
            function onDateChanged() {
                if (root.analog)
                    face.requestPaint();
            }
        }
        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const c = getContext("2d");
            const s = width, m = s / 2;
            c.reset();
            // square face (none in a shape: the shape's the face)
            if (!root.round) {
                c.strokeStyle = Colors.dim;
                c.lineWidth = 1;
                c.strokeRect(0.5, 0.5, s - 1, s - 1);
            }
            // ticks: round the square's edge (or a circle), quarters longer
            for (let i = 0; i < 60; i++) {
                const a = i / 60 * Math.PI * 2;
                const dx = Math.sin(a), dy = -Math.cos(a);
                // distance from centre to the square's edge in this direction
                const r = root.round ? m - 4 : (m - 4) / Math.max(Math.abs(dx), Math.abs(dy));
                const len = i % 15 === 0 ? 12 : i % 5 === 0 ? 7 : 2;
                c.strokeStyle = i % 5 === 0 ? Colors.accent : Colors.dim;
                c.lineWidth = i % 15 === 0 ? 3 : 1;
                c.beginPath();
                c.moveTo(m + dx * r, m + dy * r);
                c.lineTo(m + dx * (r - len), m + dy * (r - len));
                c.stroke();
            }
            const d = clock.date;
            const hand = (frac, len, w, col) => {
                const a = frac * Math.PI * 2;
                c.strokeStyle = col;
                c.lineWidth = w;
                c.lineCap = root.round ? "round" : "square";
                c.beginPath();
                c.moveTo(m, m);
                c.lineTo(m + Math.sin(a) * len, m - Math.cos(a) * len);
                c.stroke();
            };
            hand((d.getHours() % 12 + d.getMinutes() / 60) / 12, m * 0.5, 4, Colors.bright);
            hand((d.getMinutes() + d.getSeconds() / 60) / 60, m * 0.75, 2, Colors.accent);
            if (root.seconds)
                hand(d.getSeconds() / 60, m * 0.82, 1, Colors.mid);
            c.fillStyle = Colors.bright;
            if (root.round) {
                c.beginPath();
                c.arc(m, m, 3.5, 0, Math.PI * 2);
                c.fill();
            } else {
                c.fillRect(m - 3, m - 3, 6, 6);
            }
        }
    }
}

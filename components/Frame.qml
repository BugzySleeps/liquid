import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// A box in the current Look: square, rounded, or with a wavy edge. Use it like a Rectangle
// (color, border.width, border.color, children). `blob: true` makes it a circle in round and a
// scalloped cookie in squiggle (buttons, dots, art); `pill: true` makes it a pill in both.
Item {
    id: frame

    property color color: "transparent"
    readonly property FrameBorder border: FrameBorder {}
    property bool blob: false
    property bool pill: false
    property real radius: pill || blob ? Math.min(width, height) / 2 : Look.r(width, height)
    // small boxes (chips, fields) stay smooth in squiggle: a wave that small just looks fuzzy
    property bool wavy: Look.wavy && (blob || Math.min(width, height) >= 40)
    property real amplitude: blob ? Math.min(width, height) * 0.045 : 1.6
    property real wavelength: 18
    property int lobes: Math.max(6, Math.min(12, Math.round(Math.min(width, height) / 5)))
    property real spin: 0                        // turns a cookie (degrees)
    // glass: light catching the top of see-through surfaces (not solid ones, not empty outlines)
    readonly property bool sheen: Look.glass && color.a > 0.05 && color.a < 0.99 && !glassy && !bubble
    // the glass surfaces themselves (filled with Colors.glass): the shell's own liquid glass (GlassFill)
    readonly property bool glassy: Look.glass && Qt.colorEqual(color, Colors.glass)
    // the dark boxes on glass (tiles, wells, buttons) turn to little bubbles of it, like macOS's: see-through,
    // a touch lighter, a hairline of light round them
    readonly property bool bubble: Look.glass && !glassy && (Qt.colorEqual(color, Colors.bg1) || Qt.colorEqual(color, Colors.bg2) || Qt.colorEqual(color, Colors.bg3))
    readonly property color fill: glassy ? "transparent" : bubble ? Qt.tint(Qt.alpha(color, 0.3 + 0.55 * Look.tune.tint), Qt.rgba(1, 1, 1, Qt.colorEqual(color, Colors.bg3) ? 0.1 : 0.05)) : color
    readonly property real edgeWidth: glassy && Look.tune.shine > 0.05 ? 0 : bubble && frame.border.width === 0 ? 1 : frame.border.width
    readonly property color edgeColor: bubble && frame.border.width === 0 ? Qt.rgba(1, 1, 1, 0.05 + 0.13 * Look.tune.shine) : frame.border.color
    property bool curve: true                    // false for masks: the curve renderer doesn't draw into a hidden layer

    Loader {
        anchors.fill: parent
        active: frame.glassy
        // in squiggle the glass takes the wavy outline itself, so its rim of light follows the waves
        sourceComponent: GlassFill {
            readonly property real waveInset: frame.amplitude + frame.border.width / 2
            radius: !Look.round ? 0 : frame.wavy && !frame.blob ? Math.max(0, Math.min(frame.radius - waveInset, frame.width / 2 - waveInset, frame.height / 2 - waveInset)) : frame.radius
            inset: frame.wavy ? (frame.blob ? frame.border.width / 2 : waveInset) : 0
            circle: frame.blob && Look.round && !frame.wavy
            wave: !frame.wavy ? Qt.vector4d(0, 0, 0, 0) : frame.blob ? Qt.vector4d(frame.amplitude, 0, frame.lobes, frame.spin * Math.PI / 180) : Qt.vector4d(frame.amplitude, frame.waves(), 0, 0)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !frame.wavy
        radius: Look.round ? frame.radius : 0
        color: frame.fill
        // glass draws its own rim of light instead
        border.width: frame.edgeWidth
        border.color: frame.edgeColor
        antialiasing: true

        Rectangle {
            anchors.fill: parent
            visible: frame.sheen
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.13)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
    }

    Shape {
        anchors.fill: parent
        visible: frame.wavy && frame.width > 0 && frame.height > 0
        preferredRendererType: frame.curve ? Shape.CurveRenderer : Shape.GeometryRenderer
        rotation: frame.blob ? frame.spin : 0

        ShapePath {
            fillColor: frame.fill
            strokeColor: frame.edgeWidth > 0 ? frame.edgeColor : "transparent"
            strokeWidth: frame.edgeWidth
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                id: outline
                path: frame.wavy ? (frame.blob ? frame.cookie() : frame.wave()) : []
            }
        }
        ShapePath {                              // the glass sheen, in the same wavy outline
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: frame.height
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.13)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
            PathPolyline {
                path: frame.sheen ? outline.path : []
            }
        }
    }

    // a scalloped circle: the radius swells `lobes` times around
    function cookie() {
        const cx = width / 2, cy = height / 2;
        const R = Math.min(width, height) / 2 - frame.border.width / 2, a = amplitude;
        const pts = [], n = 180;
        for (let i = 0; i <= n; i++) {
            const t = i / n * 2 * Math.PI;
            const r = R - a + a * Math.cos(lobes * t);
            pts.push(Qt.point(cx + r * Math.cos(t), cy + r * Math.sin(t)));
        }
        return pts;
    }

    // how many waves fit round a wavy box (wave() and the glass share it)
    function waves() {
        const inset = amplitude + frame.border.width / 2;
        const w = width - 2 * inset, h = height - 2 * inset;
        const r = Math.max(0, Math.min(radius - inset, w / 2, h / 2));
        return Math.max(4, Math.round((2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r) / wavelength));
    }

    // a rounded rectangle whose edge ripples: a whole number of waves fits the perimeter, so it closes cleanly
    function wave() {
        const a = amplitude, inset = a + frame.border.width / 2;
        const w = width - 2 * inset, h = height - 2 * inset;
        const r = Math.max(0, Math.min(radius - inset, w / 2, h / 2));
        const sx = w - 2 * r, sy = h - 2 * r, arc = Math.PI * r / 2;
        const P = 2 * sx + 2 * sy + 4 * arc;
        const k = waves();
        // edges and corners in order, clockwise from the top-left corner's end
        const parts = [
            { len: sx, at: d => [r + d, 0, 0, -1] },
            { len: arc, at: d => corner(w - r, r, -Math.PI / 2 + d / Math.max(r, 1e-6)) },
            { len: sy, at: d => [w, r + d, 1, 0] },
            { len: arc, at: d => corner(w - r, h - r, d / Math.max(r, 1e-6)) },
            { len: sx, at: d => [w - r - d, h, 0, 1] },
            { len: arc, at: d => corner(r, h - r, Math.PI / 2 + d / Math.max(r, 1e-6)) },
            { len: sy, at: d => [0, h - r - d, -1, 0] },
            { len: arc, at: d => corner(r, r, Math.PI + d / Math.max(r, 1e-6)) }
        ];
        function corner(cx, cy, t) {
            return [cx + r * Math.cos(t), cy + r * Math.sin(t), Math.cos(t), Math.sin(t)];
        }
        const pts = [], step = 2;
        let s = 0;
        for (const p of parts) {
            for (let d = 0; d < p.len; d += step) {
                const [x, y, nx, ny] = p.at(d);
                const o = a * Math.sin(2 * Math.PI * k * (s + d) / P);
                pts.push(Qt.point(inset + x + nx * o, inset + y + ny * o));
            }
            s += p.len;
        }
        if (pts.length)
            pts.push(pts[0]);
        return pts;
    }
}

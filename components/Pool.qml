import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

// A full-screen pool of the liquid (shaders/liquid.frag, the lock's) over the wallpaper, blurred and
// dimmed. Set `level` (0 empty … 1 full) and `rough` (extra chop, e.g. while it floods in); drop
// ripples with ripple(x, strength); swell(x) is how far the surface at x stands off its resting height,
// so things can ride the waves. It only animates while visible.
Item {
    id: pool

    property real level: 0
    property real rough: 0
    property real dim: 0.45                      // how much of the blurred wallpaper shows behind
    property real time: 0

    FrameAnimation {
        running: pool.visible
        onTriggered: pool.time += frameTime
    }

    // ripples: eight slots, reused round-robin. x in pixels, the time it started, its strength
    property int slot: 0
    property vector4d r0: Qt.vector4d(0, -99, 0, 0)
    property vector4d r1: Qt.vector4d(0, -99, 0, 0)
    property vector4d r2: Qt.vector4d(0, -99, 0, 0)
    property vector4d r3: Qt.vector4d(0, -99, 0, 0)
    property vector4d r4: Qt.vector4d(0, -99, 0, 0)
    property vector4d r5: Qt.vector4d(0, -99, 0, 0)
    property vector4d r6: Qt.vector4d(0, -99, 0, 0)
    property vector4d r7: Qt.vector4d(0, -99, 0, 0)

    function ripple(x, strength) {
        pool["r" + slot] = Qt.vector4d(x, time, strength, 0);
        slot = (slot + 1) % 8;
    }

    // the shader's own sums
    function rippleAt(r, x) {
        const age = time - r.y;
        if (r.z <= 0 || age < 0 || age > 4)
            return 0;
        const d = Math.abs(x - r.x), front = age * 420;
        const k = Math.max(0, Math.min(1, (front - d) / 160));
        return Math.sin(d * 0.045 - age * 11) * 16 * r.z * k * k * (3 - 2 * k) * Math.exp(-age * 1.3) * Math.exp(-d * 0.0022);
    }
    function swell(x) {
        const h = (Math.sin(x * 0.0061 + time * 0.9) * 9 + Math.sin(x * 0.0123 - time * 1.4) * 5 + Math.sin(x * 0.0271 + time * 2.3) * 2) * (1 + rough * 2.5);
        return h + rippleAt(r0, x) + rippleAt(r1, x) + rippleAt(r2, x) + rippleAt(r3, x) + rippleAt(r4, x) + rippleAt(r5, x) + rippleAt(r6, x) + rippleAt(r7, x);
    }

    Image {
        id: wall
        anchors.fill: parent
        source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: pool.width
        sourceSize.height: pool.height
        visible: false
    }
    Item {
        id: backdrop
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: Colors.bg
        }
        FastBlur {
            anchors.fill: parent
            source: wall
            radius: 64
            opacity: pool.dim
        }
    }
    ShaderEffect {
        anchors.fill: parent
        property variant source: ShaderEffectSource {
            sourceItem: backdrop
            hideSource: true
        }
        property size size: Qt.size(width, height)
        property real time: pool.time
        property real level: pool.level
        property real rough: pool.rough
        property color tint: Colors.accent
        property color glow: Colors.bright
        property color deep: Colors.bg
        property vector4d r0: pool.r0
        property vector4d r1: pool.r1
        property vector4d r2: pool.r2
        property vector4d r3: pool.r3
        property vector4d r4: pool.r4
        property vector4d r5: pool.r5
        property vector4d r6: pool.r6
        property vector4d r7: pool.r7
        fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
    }
}

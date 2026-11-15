import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.desktop

// What the lock screen shows (in the session lock, or the preview). ekitai = 液体, "liquid": glowing
// liquid fills the screen from the bottom (shaders/liquid.frag) over the blurred wallpaper, and the login
// box floats on its surface. Every key drops a ripple; a wrong password splashes; unlocking drains it.
Item {
    id: view

    property string screenName: ""

    // ── the liquid ─────────────────────────────────────────
    property real time: 0
    property real level: 0                       // 0 empty … 1 full
    property real rough: 1                       // extra chop: high while filling, splashes on a wrong password
    readonly property real rest: 0.4             // where it settles
    property real fade: 0                        // everything but the liquid fades in after it rises

    FrameAnimation {
        running: true
        onTriggered: view.time += frameTime
    }

    // the first lock of the session (at login) opens with the intro instead; decided once, as it opens
    property real logo: 0                        // the ekitai logo (the drop and ripples), under the liquid
    Component.onCompleted: {
        (Lock.boot ? introAnim : fill).start();
        if (Lock.boot)
            dripTimer.start();
        Sounds.lock(Lock.boot ? "intro" : "fill");      // sounds/make.py times each one to its animation
    }

    // the intro's drop lands (420 ms falling) just as the liquid starts to rise, 0.7 s in (the sound's plop too)
    Timer {
        id: dripTimer
        interval: 280
        onTriggered: introLogo.drip()
    }

    ParallelAnimation {
        id: fill
        NumberAnimation {
            target: view
            property: "level"
            from: 0
            to: view.rest
            duration: 1700
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: view
            property: "rough"
            from: 1
            to: 0
            duration: 2600
            easing.type: Easing.OutQuad
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 350
            }
            NumberAnimation {
                target: view
                property: "fade"
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.OutCubic
            }
        }
    }

    // the intro: the logo glows on the black, its drop falls, the liquid rises over it until the screen is full, holds, then
    // drains to where it rests as the logo fades and the clock comes in
    SequentialAnimation {
        id: introAnim
        NumberAnimation {
            target: view
            property: "logo"
            from: 0
            to: 1
            duration: 700
            easing.type: Easing.OutCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: view
                property: "level"
                from: 0
                to: 1.04
                duration: 1600
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: view
                property: "rough"
                from: 1
                to: 0.35
                duration: 1600
            }
        }
        PauseAnimation {
            duration: 350
        }
        ParallelAnimation {
            NumberAnimation {
                target: view
                property: "level"
                to: view.rest
                duration: 1400
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: view
                property: "logo"
                to: 0
                duration: 900
            }
            NumberAnimation {
                target: view
                property: "rough"
                to: 0
                duration: 1800
                easing.type: Easing.OutQuad
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 600
                }
                NumberAnimation {
                    target: view
                    property: "fade"
                    from: 0
                    to: 1
                    duration: 900
                    easing.type: Easing.OutCubic
                }
            }
        }
        ScriptAction {
            script: Lock.boot = false
        }
    }

    // unlocking: a moment of "welcome back", then the liquid drains and the rest fades
    SequentialAnimation {
        id: drain
        PauseAnimation {
            duration: 380
        }
        ParallelAnimation {
            NumberAnimation {
                target: view
                property: "level"
                to: 0
                duration: 950
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: view
                property: "rough"
                to: 0.5
                duration: 400
            }
            NumberAnimation {
                target: view
                property: "fade"
                to: 0
                duration: 700
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: Lock.finish()
        }
    }

    SequentialAnimation {
        id: splash
        ScriptAction {
            script: {
                view.drop(view.width / 2 - 140, 1);
                view.drop(view.width / 2 + 140, 1);
                view.drop(view.width / 2, 1.3);
            }
        }
        NumberAnimation {
            target: view
            property: "rough"
            to: 0.9
            duration: 90
        }
        NumberAnimation {
            target: view
            property: "rough"
            to: 0
            duration: 1400
            easing.type: Easing.OutQuad
        }
    }

    Connections {
        target: Lock
        function onLeave() {
            fill.stop();
            drain.start();
            Sounds.lock("drain");
        }
        function onFailed() {
            splash.restart();
            Sounds.lock("splash");
        }
        function onBufferChanged() {
            const n = Lock.buffer.length;
            if (n !== view.typed) {
                view.drop(view.width / 2 + (Math.random() - 0.5) * 160, n > view.typed ? 0.45 : 0.25);
                if (n > view.typed)
                    Sounds.lock("drop");
                else if (n === view.typed - 1)   // one deleted (not the whole box cleared as it submits)
                    Sounds.lock("undrop");
            }
            view.typed = n;
        }
    }
    property int typed: 0

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

    function drop(x, strength) {
        view["r" + slot] = Qt.vector4d(x, time, strength, 0);
        slot = (slot + 1) % 8;
    }

    // the surface height at x, the same sums as the shader (so the box rides the real waves)
    function ripple(r, x) {
        const age = time - r.y;
        if (r.z <= 0 || age < 0 || age > 4)
            return 0;
        const d = Math.abs(x - r.x), front = age * 420;
        const t = Math.max(0, Math.min(1, (front - d) / 160));
        const env = t * t * (3 - 2 * t) * Math.exp(-age * 1.3) * Math.exp(-d * 0.0022);
        return Math.sin(d * 0.045 - age * 11) * 16 * r.z * env;
    }
    function surfaceAt(x) {
        let h = (Math.sin(x * 0.0061 + time * 0.9) * 9 + Math.sin(x * 0.0123 - time * 1.4) * 5 + Math.sin(x * 0.0271 + time * 2.3) * 2) * (1 + rough * 2.5);
        h += ripple(r0, x) + ripple(r1, x) + ripple(r2, x) + ripple(r3, x) + ripple(r4, x) + ripple(r5, x) + ripple(r6, x) + ripple(r7, x);
        return height * (1 - level) + h;
    }

    // ── the picture: the wallpaper, blurred and dimmed, as the shader's background ──
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
    }
    Image {
        id: wall
        anchors.fill: parent
        source: Colors.wallpaper ? "file://" + Colors.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: view.width
        sourceSize.height: view.height
        asynchronous: false
    }
    Item {
        id: backdrop
        anchors.fill: parent
        FastBlur {
            anchors.fill: parent
            source: wall
            radius: 64
        }
        Rectangle {
            anchors.fill: parent
            color: Colors.bg
            opacity: 0.5
        }
        Column {                                 // the intro's logo
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            opacity: view.logo
            scale: 0.92 + 0.08 * view.logo
            spacing: 6
            Logo {
                id: introLogo
                anchors.horizontalCenter: parent.horizontalCenter
                width: 190
                height: 190
                color: Colors.bright
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "e k i t a i"
                font.pixelSize: Style.px(18)
                font.letterSpacing: 6
                color: Colors.accent
            }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: view.level > 0.001 || view.fade > 0 ? 1 : 0     // drained and faded: just the wallpaper
        property variant source: ShaderEffectSource {
            sourceItem: backdrop
            hideSource: true
        }
        property size size: Qt.size(width, height)
        property real time: view.time
        property real level: view.level
        property real rough: view.rough
        property color tint: Colors.accent
        property color glow: Colors.bright
        property color deep: Colors.bg
        property vector4d r0: view.r0
        property vector4d r1: view.r1
        property vector4d r2: view.r2
        property vector4d r3: view.r3
        property vector4d r4: view.r4
        property vector4d r5: view.r5
        property vector4d r6: view.r6
        property vector4d r7: view.r7
        fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
    }

    // ── the clock, above the liquid ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.height * 0.17 + (1 - view.fade) * -16
        opacity: view.fade
        spacing: 4

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Style.px(Math.round(view.height * 0.14))
            font.bold: true
            font.letterSpacing: -3
            color: Colors.bright
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toLowerCase()
            font.pixelSize: Style.px(15)
            font.letterSpacing: 2
            color: Colors.accent
        }
    }

    // ── the lock screen's widgets (they can float on the liquid); editable in the preview ──
    Board {
        id: lockBoard
        anchors.fill: parent
        board: "lock"
        screenName: view.screenName
        first: view.screenName === (Quickshell.screens[0]?.name ?? "")
        editable: Lock.preview
        surface: view.surfaceAt
        opacity: view.fade
        Keys.onEscapePressed: {
            if (!lockBoard.back())
                input.forceActiveFocus();
        }
    }

    // ── the login box, floating on the surface ──
    Frame {
        id: box
        width: 400
        height: boxCol.implicitHeight + 36
        readonly property real cx: view.width / 2
        readonly property real surf: view.surfaceAt(cx)
        x: cx - width / 2
        y: surf - height + 18                    // its bottom edge just under the surface
        rotation: Math.atan((view.surfaceAt(cx + 120) - view.surfaceAt(cx - 120)) / 240) * 180 / Math.PI * 0.6
        opacity: view.fade
        color: Colors.glass
        border.width: Style.line
        border.color: Lock.phase === "fail" ? Colors.alert : Lock.phase === "welcome" ? Colors.bright : Colors.faint

        Column {
            id: boxCol
            x: 20
            y: 18
            width: parent.width - 40
            spacing: 14

            RowLayout {
                width: parent.width
                Txt {
                    text: Sys.user + "@" + Sys.host
                    font.bold: true
                    color: Colors.bright
                }
                Item {
                    Layout.fillWidth: true
                }
                Txt {
                    text: "locked " + Qt.formatTime(Lock.since, "HH:mm")
                    font.pixelSize: Style.small
                    color: Colors.dim
                }
            }

            // ❯ ●●●●●▌
            Row {
                height: 22
                spacing: 8
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❯"
                    font.pixelSize: Style.px(16)
                    font.bold: true
                    color: Lock.phase === "fail" ? Colors.alert : Colors.accent
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Repeater {
                        model: Math.min(Lock.buffer.length, 22)
                        Frame {
                            blob: true
                            width: 10
                            height: 10
                            color: Colors.accent
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Style.fast
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Lock.phase !== "checking" && Lock.phase !== "welcome"
                    width: 8
                    height: 16
                    radius: Look.round ? 2 : 0
                    color: Colors.accent
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PropertyAction {
                            value: 1
                        }
                        PauseAnimation {
                            duration: 530
                        }
                        PropertyAction {
                            value: 0
                        }
                        PauseAnimation {
                            duration: 530
                        }
                    }
                }
            }

            Txt {
                id: status
                width: parent.width
                property int spin: 0
                readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
                Timer {
                    running: Lock.phase === "checking"
                    interval: 80
                    repeat: true
                    onTriggered: status.spin = (status.spin + 1) % 10
                }
                text: Lock.phase === "checking" ? status.frames[status.spin] + " authenticating"
                    : Lock.phase === "welcome" ? "󰄬 welcome back"
                    : Lock.phase === "fail" ? "󰅖 wrong password" + (Lock.fails > 1 ? "  ×" + Lock.fails : "")
                    : Lock.preview && Widgets.editing ? "editing the lock screen's widgets · right-click to add"
                    : Lock.preview ? "preview · enter unlocks, type fail for a wrong one · esc"
                    : "enter your password"
                font.pixelSize: Style.small
                color: Lock.phase === "fail" ? Colors.alert : Lock.phase === "welcome" ? Colors.bright : Colors.mid
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── typing: a hidden field takes the keys (repeat, paste and so on work as usual) ──
    TextInput {
        id: input
        width: 0
        height: 0
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        enabled: Lock.phase !== "checking" && Lock.phase !== "welcome"
        onTextChanged: {
            if (text !== Lock.buffer)
                Lock.buffer = text;
            if (Lock.phase === "fail" && text !== "")
                Lock.phase = "";
        }
        onAccepted: Lock.submit()
        Keys.onEscapePressed: {
            if (lockBoard.back())
                return;
            if (Lock.preview)
                Lock.finish();
            else
                text = "";
        }
        Component.onCompleted: forceActiveFocus()
        Connections {
            target: Lock
            function onBufferChanged() {
                if (Lock.buffer !== input.text)
                    input.text = Lock.buffer;
            }
        }
    }

    MouseArea {                                  // a click anywhere puts the keys back in the field
        anchors.fill: parent
        z: -1
        onClicked: input.forceActiveFocus()
    }
}

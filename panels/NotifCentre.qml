import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The control centre's notifications: a timeline grouped by app (the newest app on top), each group folded to
// its newest one with the rest stacked behind it; click the header to fan it out. Swipe a notification right
// (or click its ×) and it pulls into a droplet and drips away while the others close up. "clear all" drains
// the whole stack, bottom first. Clicking a notification runs its default action, if it has one.
Column {
    id: root

    spacing: 6
    property var opened: ({})                    // app → fanned out
    property bool draining: false
    signal drain

    // as tall as the screen allows under everything above it (and the power row below it, `below`), so the
    // panel never runs off the bottom; it scrolls past that
    property real below: 110
    property real room: 360
    function measure() {
        const win = QsWindow.window;
        if (!win || !win.screen)
            return;
        const top = (Glass.origin(win)?.y ?? 0) + QsWindow.itemPosition(scroller).y;
        room = Math.max(110, win.screen.height - top - below);
    }
    // measured ahead, while the panel's closed, so opening it never resizes the window mid-unroll
    Component.onCompleted: measureLater.restart()
    Connections {
        target: Ui
        function onQuickChanged() {
            measureLater.restart();
        }
        function onPanelChanged() {
            root.settled = false;
            if (Ui.panel === "control")
                settle.restart();
        }
    }
    Connections {
        target: Notifs
        function onCountChanged() {
            measureLater.restart();
        }
    }
    // the list's height only animates once the panel's fully open (folding, swiping, clearing)
    property bool settled: false
    Timer {
        id: settle
        interval: 500
        onTriggered: root.settled = true
    }
    Timer {
        id: measureLater
        interval: 300                            // after the details have opened or closed
        onTriggered: root.measure()
    }

    function toggle(app) {
        opened = Object.assign({}, opened, { [app]: !opened[app] });
    }

    // every card in the list, top to bottom, so "clear all" can drain them in order
    function clearAll() {
        if (draining || !Notifs.count)
            return;
        draining = true;
        drain();
        drained.start();
    }
    Connections {
        target: Notifs
        function onDrainAsked() {
            root.clearAll();
        }
    }
    Timer {
        id: drained
        interval: 520 + Math.min(Notifs.count, 8) * 55
        onTriggered: {
            Notifs.clear();
            root.draining = false;
        }
    }

    RowLayout {
        width: parent.width
        Txt {
            Layout.fillWidth: true
            text: "notifications" + (Notifs.count ? "  " + Notifs.count : "")
            color: Colors.mid
            font.pixelSize: Style.small
            font.letterSpacing: 1
        }
        Txt {
            visible: Notifs.count > 0
            text: "󰃢 clear all"
            font.pixelSize: Style.small
            color: clearArea.containsMouse ? Colors.bright : Colors.accent
            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
            }
        }
    }

    Txt {
        visible: Notifs.count === 0
        text: "── nothing new ──"
        color: Colors.dim
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: 4
        bottomPadding: 4
    }

    Flickable {
        id: scroller
        visible: Notifs.count > 0
        width: parent.width
        height: Math.min(groups.implicitHeight, root.room)
        contentHeight: groups.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on height {
            enabled: root.settled
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: groups
            width: scroller.width
            spacing: 10

            Repeater {
                model: Notifs.groups
                Column {
                    id: group
                    required property var modelData
                    required property int index
                    readonly property bool many: modelData.items.length > 1
                    readonly property bool open: !!root.opened[modelData.app] || !many
                    // how many cards come before this group's, for the drain's order
                    readonly property int before: Notifs.groups.slice(0, index).reduce((s, g) => s + (root.opened[g.app] ? g.items.length : 1), 0)
                    width: groups.width
                    spacing: 4

                    // the app: icon, name, how many, when; click to fan out / fold
                    Item {
                        width: parent.width
                        height: 22
                        RowLayout {
                            anchors.fill: parent
                            spacing: 6
                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    implicitSize: 16
                                    source: group.modelData.icon ? (group.modelData.icon.startsWith("/") ? "file://" + group.modelData.icon : group.modelData.icon.includes("://") ? group.modelData.icon : Quickshell.iconPath(group.modelData.icon, true)) : ""
                                    visible: status === Image.Ready
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: "󰂚"
                                    font.pixelSize: 13
                                }
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: group.modelData.app.toLowerCase()
                                elide: Text.ElideRight
                                font.pixelSize: Style.small
                                font.letterSpacing: 1
                                color: Colors.mid
                            }
                            Frame {
                                visible: group.many
                                pill: true
                                Layout.preferredWidth: Math.max(18, countText.implicitWidth + 10)
                                Layout.preferredHeight: 16
                                color: Colors.bg3
                                Txt {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: group.modelData.items.length
                                    font.pixelSize: Style.small
                                    color: Colors.bright
                                }
                            }
                            Icon {
                                visible: group.many
                                text: "󰅂"
                                font.pixelSize: 11
                                color: Colors.mid
                                rotation: group.open ? 90 : 0
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Style.med
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                            Txt {
                                text: Notifs.ago(group.modelData.items[0])
                                font.pixelSize: Style.small
                                color: Colors.dim
                            }
                            Icon {
                                text: "󰅖"
                                font.pixelSize: 11
                                color: groupX.containsMouse ? Colors.alert : Colors.dim
                                MouseArea {
                                    id: groupX
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifs.dismissAll(group.modelData.items)
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: 24
                            enabled: group.many
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(group.modelData.app)
                        }
                    }

                    // folded: the newest, with the rest peeking out under it like a stack of cards
                    Item {
                        width: parent.width
                        height: stack.height + (group.open ? 0 : Math.min(group.modelData.items.length - 1, 2) * 5)
                        Behavior on height {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Repeater {
                            model: group.open ? 0 : Math.min(group.modelData.items.length - 1, 2)
                            Frame {
                                required property int index
                                x: (index + 1) * 8
                                y: stack.height - 14 + (index + 1) * 5
                                z: -1 - index
                                width: parent.width - (index + 1) * 16
                                height: 14
                                color: Colors.bg2
                                border.width: 1
                                border.color: Colors.faint
                                opacity: root.draining ? 0 : 0.8 - index * 0.25
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Style.med
                                    }
                                }
                            }
                        }
                        Column {
                            id: stack
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)
                                Card {
                                    required property var modelData
                                    required property int index
                                    n: modelData
                                    order: group.before + index
                                    width: stack.width
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // one notification: swipe it right (or ×) and it drips away
    component Card: Item {
        id: card
        property var n
        property int order: 0
        property bool leaving: false

        height: leaving ? 0 : box.height
        clip: leaving
        Behavior on height {
            NumberAnimation {
                duration: 260
                easing.type: Easing.InOutCubic
            }
        }

        // arriving: dropping in from just above
        opacity: 0
        Component.onCompleted: arrive.start()
        ParallelAnimation {
            id: arrive
            NumberAnimation {
                target: card
                property: "opacity"
                to: 1
                duration: 240
            }
            NumberAnimation {
                target: box
                property: "y"
                from: -8
                to: 0
                duration: 360
                easing.type: Easing.OutBack
            }
        }

        // leaving: pull into a droplet at the right edge, then drip down and away
        function go(delay, andDismiss) {
            if (drip.running)
                return;
            drip.wait = delay;
            drip.dismiss = andDismiss;
            drip.start();
        }
        Connections {
            target: root
            function onDrain() {
                card.go((Math.min(Notifs.count, 8) - Math.min(card.order, 7)) * 55, false);
            }
        }
        SequentialAnimation {
            id: drip
            property int wait: 0
            property bool dismiss: true
            PauseAnimation {
                duration: drip.wait
            }
            ParallelAnimation {
                NumberAnimation {
                    target: squeeze
                    property: "xScale"
                    to: 0.06
                    duration: 200
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: squeeze
                    property: "yScale"
                    to: 0.3
                    duration: 200
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: content
                    property: "opacity"
                    to: 0
                    duration: 120
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: box
                    property: "y"
                    to: 28
                    duration: 280
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    target: box
                    property: "opacity"
                    to: 0
                    duration: 280
                    easing.type: Easing.InQuad
                }
                ScriptAction {
                    script: card.leaving = true
                }
            }
            PauseAnimation {
                duration: 120
            }
            ScriptAction {
                script: if (drip.dismiss)
                    card.n.dismiss()
            }
        }

        Frame {
            id: box
            x: drag.x
            width: parent.width
            height: content.implicitHeight + 16
            color: area.containsMouse && !drip.running ? Colors.bg3 : Colors.bg2
            border.width: 1
            border.color: card.n.urgency === 2 ? Colors.alert : Colors.faint
            // squeezed toward the right edge as it turns into a droplet
            transform: Scale {
                id: squeeze
                origin.x: box.width - 10
                origin.y: box.height / 2
            }
            // a swipe fades it as it goes
            opacity: 1 - Math.max(0, drag.x) / (card.width * 1.2)

            RowLayout {
                id: content
                x: 12
                y: 8
                width: parent.width - 24
                spacing: 10
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt {
                        width: parent.width
                        text: card.n.summary
                        elide: Text.ElideRight
                        font.bold: true
                        color: Colors.bright
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: card.n.body
                        textFormat: Text.PlainText
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                    }
                    Row {
                        visible: card.n.actions.filter(a => a.identifier !== "default").length > 0
                        topPadding: 4
                        spacing: 6
                        Repeater {
                            model: card.n.actions.filter(a => a.identifier !== "default")
                            Frame {
                                required property var modelData
                                pill: true
                                width: actText.implicitWidth + 16
                                height: 20
                                color: actArea.containsMouse ? Colors.accent : Colors.bg3
                                Txt {
                                    id: actText
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    font.pixelSize: Style.small
                                    color: actArea.containsMouse ? Colors.bg : Colors.accent
                                }
                                MouseArea {
                                    id: actArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
                // a picture it came with (album art, an avatar)
                Image {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignTop
                    visible: card.n.image !== "" && status === Image.Ready
                    source: card.n.image
                    sourceSize.width: 72
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.top: parent.top
                anchors.topMargin: 6
                text: "󰅖"
                font.pixelSize: 11
                visible: area.containsMouse && !drip.running
                color: xArea.containsMouse ? Colors.alert : Colors.mid
                z: 2
                MouseArea {
                    id: xArea
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: card.go(0, true)
                }
            }
        }

        // the swipe: drag right past a third and let go to dismiss; less springs it back
        Item {
            id: drag
            x: 0
        }
        NumberAnimation {
            id: springBack
            target: drag
            property: "x"
            to: 0
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 2
        }
        MouseArea {
            id: area
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            enabled: !drip.running
            cursorShape: Qt.PointingHandCursor
            drag.target: drag
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: card.width
            drag.threshold: 6
            preventStealing: true
            property bool swiped: false
            onPressed: {
                swiped = false;
                springBack.stop();
            }
            onPositionChanged: if (drag.active)
                swiped = true
            onReleased: {
                if (!swiped)
                    return;
                if (drag.x > card.width / 3)
                    card.go(0, true);
                else
                    springBack.start();
            }
            onClicked: {
                if (swiped)
                    return;
                const main = card.n.actions.find(a => a.identifier === "default");
                if (main)
                    main.invoke();
                card.go(0, true);
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// A board of widgets on one screen: the desktop's, or the lock screen's. Shows that board's widgets,
// and in its edit mode the dimmed backdrop, snap grid, settings box, toolbar and right-click menu.
//   right-click = menu · drag = move · corner = resize · Esc = done
Item {
    id: root

    property string board: "desktop"
    property string screenName: ""
    property bool first: true                   // the first screen gets the toolbar, and orphaned widgets
    property bool editable: true                 // the lock screen's board is only editable in its preview
    property var surface: null                   // x → the liquid's height there (lock screen): floating widgets ride it

    readonly property bool editing: editable && Widgets.editing && Widgets.board === board
    readonly property bool menuHere: editable && Widgets.menuOpen && Widgets.menuBoard === board && Widgets.menuScreen === screenName
    readonly property var mine: Widgets.items.filter(i => i.board === board && (i.screen === screenName || (first && !Quickshell.screens.some(s => s.name === i.screen))))

    // Esc, for the window hosting this board: steps back out of the menu, typing, selection, edit mode
    function back() {
        if (Widgets.menuOpen)
            Widgets.menuOpen = false;
        else if (Widgets.typing)
            Widgets.typing = "";
        else if (Widgets.selected)
            Widgets.selected = "";
        else if (editing)
            Widgets.editing = false;
        else
            return false;
        return true;
    }

    // edit mode: dim everything behind, draw the grid
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        opacity: root.editing ? (root.board === "lock" ? 0.35 : 0.7) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.med
            }
        }
    }
    Canvas {
        anchors.fill: parent
        visible: root.editing && Widgets.snap
        onVisibleChanged: if (visible)
            requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = Colors.dim;
            const g = Widgets.grid;
            for (let x = 0; x < width; x += g)
                for (let y = 0; y < height; y += g)
                    c.fillRect(x, y, (x / g) % 4 === 0 && (y / g) % 4 === 0 ? 2 : 1, (x / g) % 4 === 0 && (y / g) % 4 === 0 ? 2 : 1);
        }
    }

    // the board itself: right-click for the menu, left-click to clear things
    MouseArea {
        anchors.fill: parent
        enabled: root.editable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            root.forceActiveFocus();
            if (e.button === Qt.RightButton) {
                Widgets.openMenu(root.board, root.screenName, e.x, e.y);
            } else {
                Widgets.menuOpen = false;
                Widgets.selected = "";
                Widgets.typing = "";
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.mine
        }
        WidgetFrame {
            editing: root.editing
            surface: root.surface
        }
    }

    WidgetSettings {
        z: 10
        board: root.board
        w: root.editing ? root.mine.find(i => i.uid === Widgets.selected) ?? null : null
    }

    // ── the edit toolbar ─────────────────────────
    Frame {
        z: 10
        visible: root.editing && root.first
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52
        width: bar.implicitWidth + 2
        height: 32
        color: Colors.glass
        border.width: Style.line
        border.color: Colors.faint

        RowLayout {
            id: bar
            x: 1
            height: parent.height
            spacing: 0
            Rectangle {
                Layout.fillHeight: true
                Layout.margins: Look.round ? 3 : 1
                implicitWidth: editLabel.implicitWidth + 20
                radius: Look.round ? height / 2 : 0
                color: Colors.accent
                Txt {
                    id: editLabel
                    anchors.centerIn: parent
                    text: root.board === "lock" ? "󰌾 EDIT LOCK SCREEN" : "󰏫 EDIT WIDGETS"
                    font.bold: true
                    font.letterSpacing: 1
                    color: Colors.bg
                }
            }
            Txt {
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: (root.board === "lock" ? "floating ones ride the liquid" : "workspace " + Widgets.workspace) + "  ·  drag to move, corner to resize"
                font.pixelSize: Style.small
                color: Colors.mid
            }
            Chip {
                Layout.rightMargin: 4
                text: "󰋱 snap"
                on: Widgets.snap
                onClicked: Widgets.snap = !Widgets.snap
            }
            Chip {
                Layout.rightMargin: 4
                text: "󰐕 add"
                onClicked: Widgets.openMenu(root.board, root.screenName, root.width / 2 - 130, 92)
            }
            Chip {
                Layout.rightMargin: 6
                text: "done"
                on: true
                onClicked: Widgets.editing = false
            }
        }
    }

    DeskMenu {
        z: 20
        board: root.board
        screenName: root.screenName
        visible: root.menuHere
    }
}

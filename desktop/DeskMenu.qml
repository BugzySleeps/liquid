import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.components

// Right-click on the desktop: add a widget where you clicked, edit widgets, change rice.
Frame {
    id: menu

    required property string screenName
    property string board: "desktop"

    width: 260
    height: col.implicitHeight + 2
    x: Math.min(Widgets.menuX, parent.width - width - 8)
    y: Math.min(Widgets.menuY, parent.height - height - 8)
    color: Colors.glass
    border.width: Style.line
    border.color: Colors.faint

    MouseArea {
        anchors.fill: parent
    }

    component Row_: Rectangle {
        id: r
        property string icon
        property string label
        property string hint
        property bool dim: false
        signal picked
        width: col.width
        height: 30
        color: a.containsMouse ? Colors.accent : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Icon {
                Layout.preferredWidth: 16
                text: r.icon
                font.pixelSize: 14
                color: a.containsMouse ? Colors.bg : r.dim ? Colors.mid : Colors.accent
            }
            Txt {
                text: r.label
                font.bold: a.containsMouse
                color: a.containsMouse ? Colors.bg : r.dim ? Colors.mid : Colors.bright
            }
            Txt {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: r.hint
                font.pixelSize: Style.small
                color: a.containsMouse ? Colors.bg2 : Colors.dim
            }
        }
        MouseArea {
            id: a
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: r.picked()
        }
    }

    Column {
        id: col
        x: 1
        y: 1
        width: parent.width - 2

        Txt {
            x: 10
            height: 26
            text: "ADD WIDGET"
            font.pixelSize: Style.small
            font.letterSpacing: 2
            color: Colors.mid
        }

        Repeater {
            model: Widgets.order
            Row_ {
                required property string modelData
                readonly property var t: Widgets.types[modelData]
                readonly property bool placed: !!t.single && Widgets.items.some(i => i.type === modelData && i.board === menu.board)
                icon: t.icon
                label: t.title
                hint: placed ? "placed" : t.desc
                dim: placed
                onPicked: Widgets.add(modelData, menu.screenName, Widgets.menuX, Widgets.menuY, menu.board)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colors.faint
        }

        Row_ {
            icon: "󰏫"
            label: Widgets.editing && Widgets.board === menu.board ? "done editing" : "edit widgets"
            hint: menu.board === "desktop" ? "super+w" : ""
            onPicked: {
                Widgets.menuOpen = false;
                Widgets.edit(menu.board);
            }
        }
        Row_ {
            visible: menu.board === "desktop"
            icon: "󰌾"
            label: "edit lock screen"
            hint: "in its preview"
            onPicked: {
                Widgets.menuOpen = false;
                Lock.openEditor();
            }
        }
        Row_ {
            icon: Look.wavy ? "󰏰" : Look.round ? "󰄰" : "󰝤"
            label: "shape: " + Look.shape
            hint: "click to cycle"
            onPicked: Look.set(Look.shapes[(Look.shapes.indexOf(Look.shape) + 1) % Look.shapes.length])
        }
        Row_ {
            icon: "󰂵"
            label: "glass: " + (Look.glass ? "on" : "off")
            hint: "click to toggle"
            onPicked: Look.setGlass(!Look.glass)
        }
        Row_ {
            visible: menu.board === "desktop"
            icon: "󰒓"
            label: "settings"
            hint: "super+i"
            onPicked: {
                Widgets.menuOpen = false;
                Settings.open = true;
            }
        }
        Row_ {
            visible: menu.board === "desktop"
            icon: "󰸉"
            label: "change wallpaper"
            hint: "super+t"
            onPicked: {
                Widgets.menuOpen = false;
                Ui.openPicker();
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// Clipboard history (SUPER+SHIFT+V), in the launcher's style:   📋 ❯ search_
//   type to filter · ↑/↓ to move · Enter = copy it back · Delete = forget it · Ctrl+Delete = forget all
PanelWindow {
    id: win

    readonly property bool open: Clip.open
    property real t: open ? 1 : 0
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
    margins.top: Math.round((screen?.height ?? 900) * 0.14)
    implicitWidth: 600
    implicitHeight: frame.height + 4

    WlrLayershell.namespace: "ekitai-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            Ui.launcher = false;
            input.text = "";
            list.currentIndex = 0;
            input.forceActiveFocus();
        }
    }

    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        return q ? Clip.items.filter(i => i.kind === "text" ? i.text.toLowerCase().includes(q) : "image".includes(q)) : Clip.items;
    }

    function ago(ms) {
        const s = Math.round((Date.now() - ms) / 1000);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d";
    }

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
                    Icon {
                        anchors.centerIn: parent
                        text: "󰅌"
                        font.pixelSize: 18
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
                            const cur = win.results[list.currentIndex];
                            if (e.key === Qt.Key_Escape) {
                                Clip.open = false;
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (cur)
                                    Clip.use(cur);
                            } else if (e.key === Qt.Key_Delete && e.modifiers & Qt.ControlModifier) {
                                Clip.clear();
                            } else if (e.key === Qt.Key_Delete) {
                                if (cur)
                                    Clip.remove(cur);
                            } else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                            } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
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
                        text: "search the clipboard"
                        color: Colors.dim
                        font.pixelSize: Style.px(13)
                    }
                }
                Txt {
                    Layout.rightMargin: 14
                    text: win.results.length + "/" + Clip.items.length
                    color: Colors.mid
                    font.pixelSize: Style.small
                }
            }

            Item {
                width: parent.width
                height: 4
            }

            Txt {
                visible: Clip.items.length === 0
                width: parent.width
                height: 64
                horizontalAlignment: Text.AlignHCenter
                text: "nothing copied yet"
                color: Colors.mid
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, 440)
                clip: true
                model: win.results
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
                    readonly property bool image: modelData.kind === "image"
                    width: list.width
                    height: image ? 84 : 46

                    // an image: its thumbnail
                    Rectangle {
                        id: thumb
                        visible: row.image
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 68
                        radius: Look.round ? 8 : 0
                        color: Colors.bg1
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: row.image ? "file://" + row.modelData.path : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 240
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.left: row.image ? thumb.right : parent.left
                        anchors.leftMargin: 14
                        anchors.right: when.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            width: parent.width
                            text: row.image ? "image" : row.modelData.text.replace(/\s+/g, " ").trim()
                            font.pixelSize: Style.px(12)
                            font.bold: row.current
                            elide: Text.ElideRight
                            maximumLineCount: row.image ? 1 : 2
                            wrapMode: Text.Wrap
                            color: row.current ? Colors.bg : Colors.bright
                        }
                        Txt {
                            visible: !row.image && row.modelData.text.length > 80
                            text: row.modelData.text?.length + " characters"
                            font.pixelSize: Style.small
                            color: row.current ? Colors.bg2 : Colors.mid
                        }
                    }

                    Txt {
                        id: when
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.ago(row.modelData.time)
                        font.pixelSize: Style.small
                        color: row.current ? Colors.bg2 : Colors.dim
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onEntered: list.currentIndex = row.index
                        onClicked: e => e.button === Qt.MiddleButton ? Clip.remove(row.modelData) : Clip.use(row.modelData)
                    }
                }
            }

            Txt {
                width: parent.width
                height: 26
                horizontalAlignment: Text.AlignHCenter
                text: "⏎ copy   del forget   ctrl+del forget all   esc close"
                font.pixelSize: Style.small
                color: Colors.dim
            }
        }
    }

    HyprlandFocusGrab {
        active: win.open
        windows: [win]
        onCleared: Clip.open = false
    }
}

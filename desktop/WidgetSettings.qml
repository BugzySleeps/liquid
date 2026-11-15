import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Settings for the selected widget (edit mode), beside it: which workspaces, box or bare,
// the widget's own options, duplicate / delete.
Frame {
    id: box

    property var w: null
    property string board: "desktop"
    readonly property var t: w ? Widgets.types[w.type] : null

    visible: !!w
    width: 264
    height: col.implicitHeight + 24
    color: Colors.glass
    border.width: Style.line
    border.color: Colors.faint

    // to the right of the widget if it fits, else to the left; kept on screen
    x: !w ? 0 : w.x + w.w + 16 + width < parent.width ? w.x + w.w + 16 : Math.max(8, w.x - width - 16)
    y: !w ? 0 : Math.max(56, Math.min(parent.height - height - 8, w.y))

    // swallow clicks so the desktop underneath doesn't deselect
    MouseArea {
        anchors.fill: parent
    }

    component Label: Txt {
        font.pixelSize: Style.small
        font.letterSpacing: 1
        color: Colors.mid
    }

    Column {
        id: col
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        RowLayout {
            width: parent.width
            Icon {
                text: box.t?.icon ?? ""
            }
            Txt {
                Layout.fillWidth: true
                text: box.t?.title ?? ""
                font.bold: true
                color: Colors.bright
            }
            IconBtn {
                icon: "󰅖"
                size: 22
                iconSize: 12
                onClicked: Widgets.selected = ""
            }
        }

        // ── lock screen: float on the liquid, or stay put ──
        Column {
            visible: box.board === "lock"
            width: parent.width
            spacing: 5
            Label {
                text: "ON THE LIQUID"
            }
            Row {
                spacing: 4
                Chip {
                    text: "󰈈 float"
                    on: box.w?.props.float ?? false
                    onClicked: Widgets.setProp(box.w, "float", true)
                }
                Chip {
                    text: "fixed"
                    on: !(box.w?.props.float ?? false)
                    onClicked: {
                        // stay where it was floating
                        box.w.y = Math.max(0, Math.round(box.parent.surface ? box.parent.surface(box.w.x + box.w.w / 2) - box.w.h * 0.75 : box.w.y));
                        Widgets.setProp(box.w, "float", false);
                    }
                }
            }
        }

        // ── workspaces ───────────────────────────
        Column {
            visible: box.board === "desktop"
            width: parent.width
            spacing: 5
            Label {
                text: "SHOW ON"
            }
            Flow {
                width: parent.width
                spacing: 4
                Chip {
                    text: "all"
                    minWidth: 40
                    on: box.w?.workspaces.length === 0
                    onClicked: Widgets.setAll(box.w)
                }
                Repeater {
                    model: Widgets.workspaceCount
                    Chip {
                        required property int index
                        text: index + 1
                        on: box.w?.workspaces.includes(index + 1) ?? false
                        border.width: !on && index + 1 === Widgets.workspace ? Style.line : 0
                        border.color: Colors.mid
                        onClicked: Widgets.toggleWorkspace(box.w, index + 1)
                    }
                }
            }
        }

        // ── look ─────────────────────────────────
        Column {
            width: parent.width
            spacing: 5
            Label {
                text: "LOOK"
            }
            Row {
                spacing: 4
                Chip {
                    text: "box"
                    on: box.w?.frame ?? false
                    onClicked: {
                        box.w.frame = true;
                        Widgets.save();
                    }
                }
                Chip {
                    text: "bare"
                    on: !(box.w?.frame ?? true)
                    onClicked: {
                        box.w.frame = false;
                        Widgets.save();
                    }
                }
            }
        }

        // ── clock ────────────────────────────────
        Column {
            visible: box.w?.type === "clock"
            width: parent.width
            spacing: 5
            Label {
                text: "CLOCK"
            }
            Row {
                spacing: 4
                Chip {
                    text: "digital"
                    on: box.w?.props.style !== "analog"
                    onClicked: Widgets.setProp(box.w, "style", "digital")
                }
                Chip {
                    text: "analog"
                    on: box.w?.props.style === "analog"
                    onClicked: Widgets.setProp(box.w, "style", "analog")
                }
                Chip {
                    text: "seconds"
                    on: box.w?.props.seconds ?? false
                    onClicked: Widgets.setProp(box.w, "seconds", !box.w.props.seconds)
                }
            }
        }

        // ── weather ──────────────────────────────
        Column {
            visible: box.w?.type === "weather"
            width: parent.width
            spacing: 5
            Label {
                text: "CITY"
            }
            Field {
                width: parent.width
                placeholder: "e.g. Tokyo, then Enter"
                text: box.w?.props.city ?? ""
                onSubmitted: t => {
                    if (box.w && t.trim() !== (box.w.props.city ?? ""))
                        Widgets.setProp(box.w, "city", t.trim());
                }
            }
            Row {
                spacing: 4
                Chip {
                    text: "°C"
                    on: box.w?.props.units !== "fahrenheit"
                    onClicked: Widgets.setProp(box.w, "units", "celsius")
                }
                Chip {
                    text: "°F"
                    on: box.w?.props.units === "fahrenheit"
                    onClicked: Widgets.setProp(box.w, "units", "fahrenheit")
                }
            }
            Label {
                text: "LOCATION"
            }
            Row {
                spacing: 4
                Repeater {
                    // hide it while the screen's shared or recorded (the default), always, or never
                    model: [["show", "show"], ["sharing", "hide when sharing"], ["hide", "hide"]]
                    Chip {
                        required property var modelData
                        text: modelData[1]
                        on: (box.w?.props.place ?? "sharing") === modelData[0]
                        onClicked: Widgets.setProp(box.w, "place", modelData[0])
                    }
                }
            }
        }

        // ── note ─────────────────────────────────
        Column {
            visible: box.w?.type === "note"
            width: parent.width
            spacing: 5
            Label {
                text: "TEXT"
            }
            Row {
                spacing: 4
                Chip {
                    text: "󰎚 scratchpad"
                    on: box.w?.props.shared ?? false
                    onClicked: Widgets.setProp(box.w, "shared", true)
                }
                Chip {
                    text: "own text"
                    on: !(box.w?.props.shared ?? false)
                    onClicked: Widgets.setProp(box.w, "shared", false)
                }
            }
            Label {
                text: "TEXT SIZE"
            }
            Row {
                spacing: 4
                Repeater {
                    model: [["s", 11], ["m", 13], ["l", 17], ["xl", 24]]
                    Chip {
                        required property var modelData
                        text: modelData[0]
                        on: (box.w?.props.size ?? 13) === modelData[1]
                        onClicked: Widgets.setProp(box.w, "size", modelData[1])
                    }
                }
            }
        }

        // ── image ────────────────────────────────
        Column {
            visible: box.w?.type === "image"
            width: parent.width
            spacing: 5
            Label {
                text: "PICTURE"
            }
            Field {
                width: parent.width
                placeholder: "~/Pictures/…, then Enter"
                text: box.w?.props.path ?? ""
                onSubmitted: t => {
                    if (box.w && t.trim() !== (box.w.props.path ?? ""))
                        Widgets.setProp(box.w, "path", t.trim());
                }
            }
            Row {
                spacing: 4
                Chip {
                    text: "tint green"
                    on: box.w?.props.tint ?? true
                    onClicked: Widgets.setProp(box.w, "tint", !(box.w.props.tint ?? true))
                }
            }
        }

        // ── actions ──────────────────────────────
        Rectangle {
            width: parent.width
            height: 1
            color: Colors.faint
        }
        Row {
            spacing: 6
            Chip {
                visible: !(box.t?.single ?? false)
                text: "󰆏 duplicate"
                onClicked: Widgets.duplicate(box.w.uid)
            }
            Chip {
                text: "󰅖 remove"
                onClicked: Widgets.remove(box.w.uid)
            }
        }
    }
}

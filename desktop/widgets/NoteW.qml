import QtQuick
import qs.config
import qs.services
import qs.components

// Text on the desktop. Double-click to type; click elsewhere or Esc to finish. Saves as you type.
// Set to "scratchpad" (the default), it shows the shared scratchpad, the same text as the control
// centre's notes; otherwise it keeps its own text.
Item {
    id: root
    property var wd

    readonly property bool typing: Widgets.typing === wd?.uid
    readonly property bool shared: wd?.props.shared ?? false
    readonly property string source: shared ? Widgets.scratch : (wd?.props.text ?? "")

    // follow changes made elsewhere (the control centre), except while typing here
    onSourceChanged: if (!typing && edit.text !== source)
        edit.text = source
    Component.onCompleted: edit.text = source

    onTypingChanged: if (typing)
        edit.forceActiveFocus()

    Flickable {
        anchors.fill: parent
        contentHeight: edit.implicitHeight
        clip: true
        interactive: contentHeight > height

        TextEdit {
            id: edit
            width: parent.width
            readOnly: !root.typing
            wrapMode: TextEdit.Wrap
            color: Colors.accent
            selectionColor: Colors.accent
            selectedTextColor: Colors.bg
            font.family: Style.font
            font.pixelSize: Style.px(root.wd?.props.size ?? 13)
            cursorVisible: root.typing
            cursorDelegate: Rectangle {
                width: 7
                color: Colors.accent
                visible: root.typing
            }
            onTextChanged: if (root.typing && root.wd)
                saveLater.restart()
            Keys.onEscapePressed: Widgets.typing = ""
        }
    }

    Timer {
        id: saveLater
        interval: 600
        onTriggered: root.shared ? Widgets.setScratch(edit.text) : Widgets.setProp(root.wd, "text", edit.text)
    }

    Txt {
        visible: edit.text === "" && !root.typing
        anchors.centerIn: parent
        text: "double-click to write"
        color: Colors.dim
    }

    // a block in the corner while typing, like a terminal in insert mode
    Txt {
        visible: root.typing
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "-- INSERT --"
        font.pixelSize: Style.small
        color: Colors.mid
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.typing && !Widgets.editing && root.wd?.board !== "lock"     // no typing on the lock screen
        onDoubleClicked: Widgets.typing = root.wd.uid
    }
}

import QtQuick
import qs.config

// A one-line text box. Emits submitted(text) on Enter or when it loses focus (`secret`: hidden, and only on Enter).
Frame {
    id: root
    pill: true

    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    function forceFocus() {
        input.forceActiveFocus();
    }
    signal submitted(string text)

    implicitHeight: 26
    color: Colors.bg2
    border.width: input.activeFocus ? Style.line : 0
    border.color: Colors.accent

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Colors.bright
        selectionColor: Colors.accent
        selectedTextColor: Colors.bg
        font.family: Style.font
        font.pixelSize: Style.text
        onAccepted: root.submitted(text)
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        onEditingFinished: if (!root.secret)
            root.submitted(text)
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder
        color: Colors.dim
        font.family: Style.font
        font.pixelSize: Style.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}

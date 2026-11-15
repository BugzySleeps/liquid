import QtQuick
import qs.config
import qs.services
import qs.components

// The previous, current and next line of the song; the current one bright and large.
Item {
    id: root
    property var wd

    readonly property bool synced: Lyrics.status === "synced"
    readonly property int i: synced ? Lyrics.index : -1
    function line(n) {
        return n >= 0 && n < Lyrics.lines.length ? Lyrics.lines[n].text : "";
    }

    Txt {
        anchors.centerIn: parent
        visible: !root.synced
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Colors.mid
        text: ({
                idle: "󰎈  play something",
                loading: "looking up lyrics…",
                none: "no lyrics for this one",
                offline: "lyrics need the internet",
                plain: Lyrics.lines.slice(0, 3).map(l => l.text).join("\n") + "\n(not synced)"
            })[Lyrics.status] ?? ""
    }

    Column {
        visible: root.synced
        anchors.centerIn: parent
        width: parent.width
        spacing: 6

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.line(root.i - 1)
            color: Colors.dim
            font.pixelSize: Style.text
        }
        Txt {
            id: current
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            text: root.i < 0 ? "♪" : root.line(root.i)
            font.pixelSize: Style.px(Math.max(14, Math.min(22, root.height * 0.18)))
            font.bold: true
            color: Colors.bright
            // each new line rises in
            onTextChanged: rise.restart()
            NumberAnimation on opacity {
                id: rise
                from: 0.2
                to: 1
                duration: Style.med
            }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.line(root.i + 1)
            color: Colors.mid
            font.pixelSize: Style.text
        }
    }
}

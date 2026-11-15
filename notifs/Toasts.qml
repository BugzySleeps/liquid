import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components

// Popups in the top-right corner, under the bar. Each one drips in: a droplet falls, splats with a
// ripple and spreads into the box. It shows a draining line for its timeout, and goes back into the
// history (control centre) when done.
//   click = dismiss · an action button runs that action
PanelWindow {
    id: win

    screen: Ui.screen
    visible: Notifs.toasts.length > 0
    color: "transparent"
    exclusiveZone: 0
    anchors {
        top: true
        right: true
    }
    margins {
        top: Style.gap
        right: Style.edge
    }
    implicitWidth: 340
    implicitHeight: Math.max(1, stack.implicitHeight)
    WlrLayershell.namespace: "ekitai-toasts"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack
        width: parent.width
        spacing: 6
        // the ones already showing glide down to make room
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Style.med
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            // a ScriptModel keeps the toasts already showing (a plain array would rebuild them all,
            // and every one would drip in again whenever a new one arrives)
            model: ScriptModel {
                values: Notifs.toasts
            }

            Item {
                id: toast
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property int timeout: critical ? 0 : modelData.expireTimeout > 0 ? modelData.expireTimeout : 6000

                width: stack.width
                height: box.height

                // dripping in: the droplet falls, then the box spreads out of where it lands
                property real fall: 0
                property real spread: 0
                readonly property real landX: width - 44
                readonly property real landY: Math.min(height / 2, 30)
                SequentialAnimation {
                    running: true
                    NumberAnimation {
                        target: toast
                        property: "fall"
                        from: 0
                        to: 1
                        duration: 240
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: toast
                        property: "spread"
                        from: 0
                        to: 1
                        duration: 460
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                Rectangle {                      // the droplet, stretched as it falls
                    visible: toast.spread < 0.3
                    width: 11
                    height: 11 + 7 * toast.fall * (1 - toast.spread * 3)
                    radius: 5.5
                    x: toast.landX - width / 2
                    y: -14 + toast.fall * (toast.landY + 14) - height / 2
                    opacity: 1 - toast.spread * 3.3
                    color: Colors.accent
                }
                Rectangle {                      // the ripple where it lands
                    readonly property real d: 10 + toast.spread * 150
                    visible: toast.spread > 0 && toast.spread < 1
                    width: d
                    height: d
                    radius: d / 2
                    x: toast.landX - d / 2
                    y: toast.landY - d / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Colors.accent
                    opacity: Math.max(0, 1 - toast.spread * 1.1)
                }

                Frame {
                    id: box
                    width: parent.width
                    height: content.implicitHeight + 20
                    color: Colors.glass
                    border.width: Style.line
                    border.color: toast.critical ? Colors.alert : Colors.faint

                    // spreads out of the droplet: sideways first, then down
                    opacity: Math.min(1, toast.spread * 2)
                    transform: Scale {
                        origin.x: toast.landX
                        origin.y: toast.landY
                        xScale: 0.03 + 0.97 * toast.spread
                        yScale: 0.06 + 0.94 * Math.pow(Math.max(0, toast.spread), 1.7)
                    }

                    Rectangle {                  // the accent strip on the left (inset in round looks)
                        x: Look.round ? 7 : 0
                        y: Look.round ? 12 : 0
                        width: 3
                        height: parent.height - 2 * y
                        radius: Look.round ? 1.5 : 0
                        color: toast.critical ? Colors.bright : Colors.accent
                    }

                    ColumnLayout {
                        id: content
                        opacity: Math.max(0, (toast.spread - 0.55) / 0.45)
                        x: 14
                        y: 10
                        width: parent.width - 26
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Txt {
                                Layout.fillWidth: true
                                text: (toast.modelData.appName || "notice").toLowerCase()
                                font.pixelSize: Style.small
                                font.letterSpacing: 1
                                color: Colors.mid
                            }
                            Txt {
                                text: Qt.formatTime(new Date(), "HH:mm")
                                font.pixelSize: Style.small
                                color: Colors.dim
                            }
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: toast.modelData.summary
                            font.bold: true
                            color: Colors.bright
                        }
                        Txt {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: toast.modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                        }
                        Row {
                            Layout.topMargin: 4
                            visible: toast.modelData.actions.length > 0
                            spacing: 6
                            Repeater {
                                model: toast.modelData.actions
                                Frame {
                                    pill: true
                                    required property var modelData
                                    width: label.implicitWidth + 16
                                    height: 22
                                    color: actArea.containsMouse ? Colors.accent : Colors.bg2
                                    Txt {
                                        id: label
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

                    // the timeout, draining right to left
                    Rectangle {
                        id: drain
                        visible: toast.timeout > 0
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        x: 3
                        height: 2
                        // animate a fraction, not the width: the width is 0 for a moment while
                        // the toast is built, which would end the animation (and the toast) at once
                        property real remaining: 1
                        width: (parent.width - 4) * remaining
                        color: Colors.mid
                        NumberAnimation on remaining {
                            running: toast.timeout > 0
                            paused: running && hover.containsMouse
                            from: 1
                            to: 0
                            duration: toast.timeout
                            onFinished: Notifs.drop(toast.modelData)
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.drop(toast.modelData)
                    }
                }
            }
        }
    }
}

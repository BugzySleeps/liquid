import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.components

// The bar: one slim borderless strip, or three floating islands (Settings.barStyle).
//   left   = 液 (launcher), workspaces, focused app
//   centre = clock + date (calendar), and the playing track with live bars (media)
//   right  = cpu, memory, wifi, volume, notifications, control centre
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Style.barHeight + Style.gap
            exclusiveZone: Ui.barVisible ? implicitHeight : 0
            color: "transparent"
            WlrLayershell.namespace: "ekitai-bar"

            // slide up out of sight when hidden (SUPER+Tab)
            property real shown: Ui.barVisible ? 1 : 0
            Behavior on shown {
                NumberAnimation {
                    duration: Style.slow
                    easing.type: Easing.OutExpo
                }
            }
            visible: shown > 0
            mask: Region {
                item: islands
            }

            Component.onCompleted: Ui.bars = [...Ui.bars, bar]
            Component.onDestruction: Ui.bars = Ui.bars.filter(b => b !== bar)

            Item {
                id: islands
                x: Style.edge
                width: parent.width - Style.edge * 2
                height: Style.barHeight
                y: Style.gap - (Style.barHeight + Style.gap) * (1 - bar.shown)
                opacity: bar.shown

                // the strip: one slim bar behind everything (Settings.barStyle "strip")
                Frame {
                    visible: Settings.barStyle === "strip"
                    anchors.fill: parent
                    color: Colors.glass
                }

                // ── left ─────────────────────────────────────────────
                Island {
                    anchors.left: parent.left

                    Rectangle {
                        width: Look.round ? 32 : 30
                        height: Style.barHeight - 2
                        y: 0
                        topLeftRadius: Look.round ? height / 2 : 0
                        bottomLeftRadius: topLeftRadius
                        color: tileArea.containsMouse ? Colors.bright : Colors.accent
                        Logo {
                            id: barLogo
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            color: Colors.bg
                        }
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onContainsMouseChanged: if (containsMouse)
                                barLogo.drip()
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.launcher ? Ui.launcher = false : Ui.openLauncher()
                        }
                    }

                    Workspaces {}

                    Sep {
                        visible: windowCell.visible
                    }

                    Cell {
                        id: windowCell
                        interactive: false
                        visible: Settings.barTitle && !!ToplevelManager.activeToplevel?.appId
                        Txt {
                            text: ToplevelManager.activeToplevel?.appId ?? ""
                            color: Colors.mid
                            Layout.maximumWidth: 160
                        }
                    }
                }

                // ── centre: the dynamic island (bar/DynamicIsland.qml, its own window) ──

                // ── right ────────────────────────────────────────────
                Island {
                    anchors.right: parent.right

                    Cell {
                        visible: Settings.barMeters
                        onClicked: Ui.toggle("control")
                        Icon {
                            text: "󰘚"
                        }
                        Meter {
                            value: Sys.cpu
                            segments: 5
                            segWidth: 4
                            segHeight: 9
                            spacing: 1
                        }
                        Txt {
                            text: Math.round(Sys.cpu * 100) + "%"
                            Layout.preferredWidth: 32
                        }
                    }

                    Sep {
                        visible: Settings.barMeters
                    }

                    Cell {
                        visible: Settings.barMeters
                        onClicked: Ui.toggle("control")
                        Icon {
                            text: "󰍛"
                        }
                        Meter {
                            value: Sys.mem
                            segments: 5
                            segWidth: 4
                            segHeight: 9
                            spacing: 1
                        }
                        Txt {
                            text: Math.round(Sys.mem * 100) + "%"
                            Layout.preferredWidth: 32
                        }
                    }

                    Sep {
                        visible: Settings.barMeters
                    }

                    Cell {
                        pad: 9
                        hint: Net.connected ? Net.name : "offline"
                        onClicked: Ui.toggle("control")
                        Icon {
                            text: Net.icon
                            color: Net.connected ? Colors.accent : Colors.mid
                        }
                    }

                    Sep {}

                    Cell {
                        pad: 9
                        hint: Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
                        onClicked: m => m.button === Qt.MiddleButton ? Audio.toggleMute() : Ui.toggle("control")
                        onScrolled: d => Audio.nudge(d * 0.05)
                        Icon {
                            text: Audio.icon
                            color: Audio.muted ? Colors.mid : Colors.accent
                        }
                    }

                    Sep {}

                    // screen recorder (wl-screenrec, ~/.config/waybar/scripts/record.sh): left = this monitor,
                    // right = drag out an area, middle = the recordings folder. Recording: a red dot and the time.
                    Cell {
                        id: rec
                        pad: 9
                        hint: Recorder.on ? "" : "record"
                        onClicked: m => Recorder.run(m.button === Qt.RightButton ? "region" : m.button === Qt.MiddleButton ? "folder" : "toggle")
                        Rectangle {
                            visible: Recorder.on
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: Colors.alert
                            SequentialAnimation on opacity {
                                running: Recorder.on
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.25
                                    duration: 600
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 600
                                }
                            }
                        }
                        Icon {
                            visible: !Recorder.on
                            text: "󰑊"
                            color: Colors.accent
                        }
                        Txt {
                            visible: Recorder.on
                            text: Recorder.time
                            color: Colors.alert
                        }
                    }

                    Sep {}

                    Cell {
                        pad: 9
                        onClicked: Ui.toggle("control")
                        Icon {
                            text: Ui.dnd ? "󰂛" : Notifs.count > 0 ? "󰂞" : "󰂚"
                            color: Notifs.count > 0 && !Ui.dnd ? Colors.bright : Colors.accent
                        }
                        Txt {
                            visible: Notifs.count > 0
                            text: Notifs.count
                            font.pixelSize: Style.small
                            color: Colors.bright
                        }
                    }

                    // control centre: a solid tile, mirroring 液 on the left
                    Rectangle {
                        width: Look.round ? 32 : 30
                        height: Style.barHeight - 2
                        topRightRadius: Look.round ? height / 2 : 0
                        bottomRightRadius: topRightRadius
                        color: ccArea.containsMouse || Ui.panel === "control" ? Colors.bright : Colors.accent
                        Icon {
                            anchors.centerIn: parent
                            text: "󰒓"
                            color: Colors.bg
                            rotation: Ui.panel === "control" ? 90 : 0
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Style.slow
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                        MouseArea {
                            id: ccArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.toggle("control")
                        }
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }
        }
    }
}

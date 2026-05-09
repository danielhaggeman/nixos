import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    color: "transparent"
    clip: true
    implicitHeight: headerRect.height + (root.expanded ? bodyRect.implicitHeight : 0)
    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property bool expanded: false
    property string openEditor: ""
    property var connections: []

    Component.onCompleted: loadConnections()

    function loadConnections() {
        var proc = Quickshell.execDetached ? "" : ""
        var output = sh("~/.config/quickshell/network/eth_panel_logic.sh list-connections")
        var lines = output.trim().split("\n").filter(function(l) { return l.length > 0 })
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("|")
            result.push({ name: p[0] || "", ip: p[1] || "", gateway: p[2] || "", active: p[3] === "true" })
        }
        connections = result
    }

    function sh(cmd) {
        return Config.sh(cmd)
    }

    Rectangle {
        id: headerRect
        width: parent.width
        height: 44
        color: "#282a36"
        radius: root.expanded ? 0 : 10

        RowLayout {
            anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
            spacing: 10

            Text { text: "󰈀"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: "#8be9fd" }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    spacing: 6
                    Text { text: "Ethernet"; color: "#f8f8f2"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                    Rectangle { width: 7; height: 7; radius: 4; color: "#50fa7b" }
                }
                Text {
                    text: root.connections.length > 0 ? (function() {
                        for (var i = 0; i < root.connections.length; i++) {
                            if (root.connections[i].active) return root.connections[i].ip || "connected"
                        }
                        return "not connected"
                    })() : "loading..."
                    color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10
                }
            }

            Text {
                text: "▼"; color: "#6272a4"; font.pixelSize: 10
                rotation: root.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 250 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.expanded = !root.expanded
                if (root.expanded) root.loadConnections()
            }
        }
    }

    Rectangle {
        id: bodyRect
        anchors.top: headerRect.bottom
        width: parent.width
        color: "#11111b"
        visible: root.expanded
        implicitHeight: bodyCol.implicitHeight + 16

        ColumnLayout {
            id: bodyCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 6

            Repeater {
                model: root.connections
                delegate: Rectangle {
                    id: connCard
                    Layout.fillWidth: true
                    radius: 10
                    color: modelData.active ? "#8be9fd08" : "#282a36"
                    border.color: modelData.active ? "#8be9fd50" : "transparent"
                    border.width: 1
                    implicitHeight: connCardCol.implicitHeight + 20

                    ColumnLayout {
                        id: connCardCol
                        anchors { left: parent.left; right: parent.right; margins: 12 }
                        y: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: modelData.active ? "#8be9fd" : "#f8f8f2"
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: badgeLabel.implicitWidth + 12; height: 16; radius: 4
                                color: modelData.active ? "#50fa7b20" : "#44475a"
                                Text {
                                    id: badgeLabel; anchors.centerIn: parent
                                    text: modelData.active ? "active" : "saved"
                                    color: modelData.active ? "#50fa7b" : "#6272a4"
                                    font.family: "JetBrains Mono"; font.pixelSize: 9
                                }
                            }
                        }
                        Text {
                            text: (modelData.ip || "no IP") + (modelData.gateway ? " · GW " + modelData.gateway : "")
                            color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10
                        }

                        Loader {
                            id: editorLoader
                            Layout.fillWidth: true
                            active: root.openEditor === modelData.name
                            sourceComponent: IPEditor {
                                connectionName: modelData.name
                                currentIp: modelData.ip
                                currentGw: modelData.gateway
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openEditor = (root.openEditor === modelData.name ? "" : modelData.name)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 34; radius: 8; color: "transparent"
                border.color: "#44475a"; border.width: 1
                Text { anchors.centerIn: parent; text: "+ Add connection"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
            }
        }
    }
}

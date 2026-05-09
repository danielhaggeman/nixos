import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    width: 340
    color: "#1e1f29"
    radius: 16
    border.color: Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    clip: true

    property bool editMode: false

    implicitHeight: content.implicitHeight + 28

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        // Header row
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "QUICK SETTINGS"
                color: "#6272a4"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                letterSpacing: 1
                Layout.fillWidth: true
            }
            Rectangle {
                width: editLbl.implicitWidth + 20; height: 22; radius: 6
                color: root.editMode ? "#bd93f915" : "transparent"
                border.color: root.editMode ? "#bd93f9" : "#44475a"; border.width: 1
                Text {
                    id: editLbl; anchors.centerIn: parent
                    text: root.editMode ? "Done" : "Edit"
                    color: root.editMode ? "#bd93f9" : "#6272a4"
                    font.family: "JetBrains Mono"; font.pixelSize: 10
                }
                MouseArea { anchors.fill: parent; onClicked: root.editMode = !root.editMode }
            }
        }

        // Toggle tiles grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8; rowSpacing: 8

            // WiFi tile
            Rectangle {
                Layout.fillWidth: true; height: 68; radius: 12
                color: "#bd93f920"
                border.color: "#bd93f940"; border.width: 1
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 4
                    Text { text: "󰤨"; font.family: "Iosevka Nerd Font"; font.pixelSize: 20; color: "#bd93f9" }
                    Text { text: "Wi-Fi"; color: "#bd93f9"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                    Text { text: "Connected"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
                }
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
            }

            // Bluetooth tile
            Rectangle {
                Layout.fillWidth: true; height: 68; radius: 12
                color: "#6272a420"
                border.color: "#6272a440"; border.width: 1
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 4
                    Text { text: "󰂯"; font.family: "Iosevka Nerd Font"; font.pixelSize: 20; color: "#6272a4" }
                    Text { text: "Bluetooth"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                    Text { text: "Off"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
                }
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bluetooth"]) }
            }
        }

        // Ethernet tile (expandable — EthernetTile.qml)
        EthernetTile {
            Layout.fillWidth: true
        }

        // Volume slider
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { text: "󰕾"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: "#6272a4" }
            Rectangle {
                Layout.fillWidth: true; height: 4; radius: 2; color: "#44475a"
                property real volPct: 0.45
                Rectangle {
                    width: parent.width * parent.volPct; height: parent.height
                    radius: 2; color: "#bd93f9"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        parent.volPct = mouseX / parent.width
                        Quickshell.execDetached(["bash", "-c", "pamixer --set-volume " + Math.round(parent.volPct * 100)])
                    }
                }
            }
            Text { text: "45%"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: "#44475a30" }

        // Settings button — opens full SettingsPopup
        Rectangle {
            id: settingsBtn
            Layout.fillWidth: true; height: 38; radius: 10
            color: settingsMouse.containsMouse ? "#44475a" : "#282a36"
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10
                Text { text: "󰒓"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: "#6272a4" }
                Text { text: "Settings"; color: "#f8f8f2"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                Text { text: "›"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 14 }
            }
            MouseArea {
                id: settingsMouse; hoverEnabled: true; anchors.fill: parent
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"])
            }
        }
    }
}

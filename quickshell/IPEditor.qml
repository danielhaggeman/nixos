import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

Rectangle {
    id: root
    color: "#1a1b26"; radius: 8
    border.color: "#44475a30"; border.width: 1
    implicitHeight: formCol.implicitHeight + 20

    required property string connectionName
    required property string currentIp
    required property string currentGw

    property bool dhcp: false

    ColumnLayout {
        id: formCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Text { text: "DHCP (automatic)"; color: "#f8f8f2"; font.family: "JetBrains Mono"; font.pixelSize: 11; Layout.fillWidth: true }
            Rectangle {
                id: dhcpSwitch; width: 34; height: 18; radius: 9
                color: root.dhcp ? "#8be9fd" : "#44475a"
                Behavior on color { ColorAnimation { duration: 200 } }
                Rectangle {
                    id: dhcpKnob; width: 14; height: 14; radius: 7; color: "#f8f8f2"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.dhcp ? 17 : 2
                    Behavior on x { NumberAnimation { duration: 200 } }
                }
                MouseArea { anchors.fill: parent; onClicked: root.dhcp = !root.dhcp }
            }
        }

        Text { text: "IP ADDRESS"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 9; letterSpacing: 0.8 }
        TextField {
            id: ipField; Layout.fillWidth: true
            text: root.currentIp ? root.currentIp.split("/")[0] : ""
            enabled: !root.dhcp; opacity: root.dhcp ? 0.4 : 1
            font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
            background: Rectangle { color: "#282a36"; radius: 7; border.color: ipField.activeFocus ? "#8be9fd80" : "#44475a"; border.width: 1 }
        }

        RowLayout { spacing: 6
            ColumnLayout {
                Text { text: "PREFIX"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 9 }
                TextField {
                    id: prefixField; width: 60
                    text: root.currentIp ? (root.currentIp.split("/")[1] || "24") : "24"
                    enabled: !root.dhcp; opacity: root.dhcp ? 0.4 : 1
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: "#44475a"; border.width: 1 }
                }
            }
            ColumnLayout { Layout.fillWidth: true
                Text { text: "GATEWAY"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 9 }
                TextField {
                    id: gwField; Layout.fillWidth: true
                    text: root.currentGw || ""
                    enabled: !root.dhcp; opacity: root.dhcp ? 0.4 : 1
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: gwField.activeFocus ? "#8be9fd80" : "#44475a"; border.width: 1 }
                }
            }
        }

        RowLayout { spacing: 6
            ColumnLayout { Layout.fillWidth: true
                Text { text: "DNS PRIMARY"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 9 }
                TextField {
                    id: dns1Field; Layout.fillWidth: true; text: "1.1.1.1"
                    enabled: !root.dhcp; opacity: root.dhcp ? 0.4 : 1
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: "#44475a"; border.width: 1 }
                }
            }
            ColumnLayout { Layout.fillWidth: true
                Text { text: "DNS SECONDARY"; color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 9 }
                TextField {
                    id: dns2Field; Layout.fillWidth: true; text: "8.8.8.8"
                    enabled: !root.dhcp; opacity: root.dhcp ? 0.4 : 1
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: "#44475a"; border.width: 1 }
                }
            }
        }

        Rectangle {
            id: applyBtn
            Layout.fillWidth: true; height: 32; radius: 7
            color: applyMouse.containsMouse ? "#8be9fd25" : "#8be9fd15"
            border.color: "#8be9fd50"; border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Text { anchors.centerIn: parent; text: "Apply via nmcli"; color: "#8be9fd"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
            MouseArea {
                id: applyMouse; hoverEnabled: true; anchors.fill: parent
                onClicked: {
                    if (root.dhcp) {
                        Config.sh("~/.config/quickshell/network/eth_panel_logic.sh apply-dhcp '" + root.connectionName + "'")
                    } else {
                        var ipPrefix = ipField.text + "/" + prefixField.text
                        Config.sh("~/.config/quickshell/network/eth_panel_logic.sh apply-static '" + root.connectionName + "' '" + ipPrefix + "' '" + gwField.text + "' '" + dns1Field.text + "' '" + dns2Field.text + "'")
                    }
                }
            }
        }
    }
}

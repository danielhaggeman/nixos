import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    width: 300
    color: "#1e1f29"
    radius: 16
    border.color: Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    clip: true
    implicitHeight: col.implicitHeight + 28

    property string activeTheme: "dracula"

    property var themes: [
        { id: "dracula",  name: "Dracula",  desc: "Deep purple & pink",       bg: "#282a36", dots: ["#bd93f9","#ff79c6","#8be9fd"] },
        { id: "wisp",     name: "Wisp",     desc: "Dreamy mauve & lavender",  bg: "#3a2545", dots: ["#5f3e65","#c8adbe","#ddbdd1"] },
        { id: "shoegaze", name: "Shoegaze", desc: "Black, white & grain",      bg: "#111111", dots: ["#222222","#888888","#f0f0f0"] },
        { id: "fawning",  name: "Fawning",  desc: "Night sky & ice blue",      bg: "#060810", dots: ["#060810","#1e3a5a","#c8ddf0"] },
        { id: "auto",     name: "Auto",     desc: "Generated from wallpaper",  bg: "#1a1b26", dots: ["#44475a","#6272a4","#bd93f9"] }
    ]

    property var draculaColors: '{"base":"#282a36","mantle":"#1e1f29","crust":"#11111b","text":"#f8f8f2","subtext0":"#6272a4","surface0":"#44475a","surface1":"#44475a","mauve":"#bd93f9","pink":"#ff79c6","blue":"#8be9fd","green":"#50fa7b","yellow":"#f1fa8c","peach":"#ffb86c","red":"#ff5555"}'
    property var wispColors: '{"base":"#2a1f33","mantle":"#221829","crust":"#180e20","text":"#f3d9d9","subtext0":"#a793b3","surface0":"#3d2850","surface1":"#4a3060","mauve":"#c8adbe","pink":"#ddbdd1","blue":"#a793b3","green":"#c8adbe","yellow":"#ddbdd1","peach":"#f3d9d9","red":"#b07090"}'
    property var shoegazeColors: '{"base":"#0a0a0a","mantle":"#080808","crust":"#050505","text":"#f0f0f0","subtext0":"#888888","surface0":"#1a1a1a","surface1":"#222222","mauve":"#d0d0d0","pink":"#e0e0e0","blue":"#c0c0c0","green":"#b0b0b0","yellow":"#e8e8e8","peach":"#c8c8c8","red":"#a0a0a0"}'
    property var fawningColors: '{"base":"#060810","mantle":"#080c14","crust":"#040608","text":"#dde8f0","subtext0":"#6a8aaa","surface0":"#0d1520","surface1":"#121e2e","mauve":"#c8ddf0","pink":"#a8c4d8","blue":"#8ab4d0","green":"#7ab0c8","yellow":"#d0e4f0","peach":"#b0cce0","red":"#6888a8"}'

    function applyTheme(themeId) {
        activeTheme = themeId
        var json = themeId === "dracula" ? draculaColors :
                   themeId === "wisp" ? wispColors :
                   themeId === "shoegaze" ? shoegazeColors :
                   themeId === "fawning" ? fawningColors : ""
        if (json) {
            Quickshell.execDetached(["bash", "-c", "echo '" + json + "' > /tmp/qs_colors.json"])
        } else if (themeId === "auto") {
            Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/wallpaper/matugen_reload.sh"])
        }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 8

        Text {
            text: "THEME"
            color: "#6272a4"; font.family: "JetBrains Mono"; font.pixelSize: 10; letterSpacing: 1
        }

        Repeater {
            model: root.themes
            delegate: Rectangle {
                Layout.fillWidth: true; height: 56; radius: 12
                color: modelData.bg
                border.color: root.activeTheme === modelData.id ? "#f8f8f2" : "transparent"
                border.width: 2

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData.dots
                            Rectangle { width: 11; height: 11; radius: 6; color: modelData }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: modelData.name; color: "#f8f8f2"; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.desc; color: "rgba(255,255,255,0.45)"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: root.applyTheme(modelData.id) }
            }
        }
    }
}

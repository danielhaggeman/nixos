import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Explicitly typed as 'color' for strict QML binding
    property color base: "#282a36"
    property color mantle: "#1e1f29"
    property color crust: "#11111b"
    property color text: "#f8f8f2"
    property color subtext0: "#6272a4"
    property color subtext1: "#a0a8c0"
    property color surface0: "#44475a"
    property color surface1: "#44475a"
    property color surface2: "#6272a4"
    property color overlay0: "#6272a4"
    property color overlay1: "#808090"
    property color overlay2: "#9090a8"
    property color blue: "#8be9fd"
    property color sapphire: "#8be9fd"
    property color peach: "#ffb86c"
    property color green: "#50fa7b"
    property color red: "#ff5555"
    property color mauve: "#bd93f9"
    property color pink: "#ff79c6"
    property color yellow: "#f1fa8c"
    property color maroon: "#ff5555"
    property color teal: "#50fa7b"

    property string rawJson: ""

    Process {
        id: themeReader
        command: ["cat", "/tmp/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && txt !== root.rawJson) {
                    root.rawJson = txt;
                    try {
                        let c = JSON.parse(txt);
                        if (c.base) root.base = c.base;
                        if (c.mantle) root.mantle = c.mantle;
                        if (c.crust) root.crust = c.crust;
                        if (c.text) root.text = c.text;
                        if (c.subtext0) root.subtext0 = c.subtext0;
                        if (c.subtext1) root.subtext1 = c.subtext1;
                        if (c.surface0) root.surface0 = c.surface0;
                        if (c.surface1) root.surface1 = c.surface1;
                        if (c.surface2) root.surface2 = c.surface2;
                        if (c.overlay0) root.overlay0 = c.overlay0;
                        if (c.overlay1) root.overlay1 = c.overlay1;
                        if (c.overlay2) root.overlay2 = c.overlay2;
                        if (c.blue) root.blue = c.blue;
                        if (c.sapphire) root.sapphire = c.sapphire;
                        if (c.peach) root.peach = c.peach;
                        if (c.green) root.green = c.green;
                        if (c.red) root.red = c.red;
                        if (c.mauve) root.mauve = c.mauve;
                        if (c.pink) root.pink = c.pink;
                        if (c.yellow) root.yellow = c.yellow;
                        if (c.maroon) root.maroon = c.maroon;
                        if (c.teal) root.teal = c.teal;
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 1000 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeReader.running = true
    }
}

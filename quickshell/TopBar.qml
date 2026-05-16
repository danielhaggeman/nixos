import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false
            
	    Caching { id: paths }

            readonly property bool ownsSharedState: modelData === Quickshell.screens[0]
            readonly property string barStateDir: paths.getRunDir("bar_state")
            readonly property string audioCachePath: barStateDir + "/audio.json"
            readonly property string networkCachePath: barStateDir + "/network.json"
            readonly property string musicCachePath: paths.getRunDir("music") + "/music_info.json"

	    Component.onCompleted: {
 	        console.log("runDir:", paths.runDir)
 	        console.log("manual path:", paths.runDir + "/workspaces")
 	        console.log("env test:", Quickshell.env("QS_RUN_WORKSPACES"))
 	        console.log("wsPath:", paths.getRunDir("workspaces"))
	    }	     	
        
            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
                function toggleUpdate() {
                    barWindow.forceUpdateShow = !barWindow.forceUpdateShow
                }
            }

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale

            function s(val) { 
                return scaler.s(val); 
            }

            property int barHeight: 32

            height: barHeight
            margins { top: 0; bottom: 0; left: 0; right: 0 }
            exclusiveZone: barHeight
            color: "transparent"

            MatugenColors {
                id: mocha
            }

            property bool showHelpIcon: false
            property bool isRecording: false
            
            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow
            
            property int workspaceCount: 8
            
            property string activeWidget: "" 
            property bool isSettingsOpen: activeWidget === "settings"

            property real settingsSlideProgress: isSettingsOpen ? 1.0 : 0.0
            Behavior on settingsSlideProgress { 
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
            }

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 500; running: true; repeat: true
                onTriggered: {
                    recPoller.running = false;
                    recPoller.running = true;
                }
            }

            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 2000; running: true; repeat: true
                onTriggered: {
                    updatePoller.running = false;
                    updatePoller.running = true;
                }
            }
            
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                                let parsed = JSON.parse(this.text);
                                
                                if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                    barWindow.showHelpIcon = parsed.topbarHelpIcon;
                                }
                                
                                if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                    barWindow.workspaceCount = parsed.workspaceCount;
                                    wsDaemon.running = false;
                                    wsDaemon.running = true;
                                }
                            }
                        } catch (e) {}
                    }
                }
            }

            Process {
                id: settingsWatcher
                command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        settingsReader.running = false;
                        settingsReader.running = true;
                        
                        settingsWatcher.running = false;
                        settingsWatcher.running = true;
                    }
                }
            }
            
            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string kbLayout: "us"
            
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0

            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/quickshell/services/bar_state_daemon.sh"]
                running: barWindow.ownsSharedState
            }

            Process {
		id: wsReader
		running: true
                command: ["bash", "-c", "cat '" + paths.getRunDir("workspaces") + "/workspaces.json' 2>/dev/null || echo '[]'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "" });
                                }
                                
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }
                                
                                let newActive = -1;

                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;

                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                }

                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }

                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "while [ ! -e '" + paths.getRunDir("workspaces") + "/workspaces.json' ]; do sleep 1; done; inotifywait -qq -e close_write,modify '" + paths.getRunDir("workspaces") + "/workspaces.json'"]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "cat '" + barWindow.musicCachePath + "' 2>/dev/null || true"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "while [ ! -e '" + barWindow.musicCachePath + "' ]; do sleep 1; done; inotifywait -qq -e close_write,modify '" + barWindow.musicCachePath + "'"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                running: barWindow.displayArtUrl && barWindow.displayArtUrl.indexOf("placeholder_blank.png") !== -1
                onTriggered: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                }
            }

            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", "cat '" + barWindow.audioCachePath + "' 2>/dev/null || echo '{\"volume\":\"0\",\"icon\":\"󰝟\",\"is_muted\":\"false\"}'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                        audioWaiter.running = false;
                        audioWaiter.running = true;
                    }
                }
            }
            Process { id: audioWaiter; command: ["bash", "-c", "while [ ! -e '" + barWindow.audioCachePath + "' ]; do sleep 1; done; inotifywait -qq -e close_write,modify '" + barWindow.audioCachePath + "'"]; onExited: { audioPoller.running = false; audioPoller.running = true; running = false; running = true; } }

            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "cat '" + barWindow.networkCachePath + "' 2>/dev/null || echo '{\"status\":\"disabled\",\"ssid\":\"\",\"icon\":\"󰤮\",\"eth_status\":\"Disconnected\"}'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                        networkWaiter.running = false;
                        networkWaiter.running = true;
                    }
                }
            }
            Process { id: networkWaiter; command: ["bash", "-c", "while [ ! -e '" + barWindow.networkCachePath + "' ]; do sleep 1; done; inotifywait -qq -e close_write,modify '" + barWindow.networkCachePath + "'"]; onExited: { networkPoller.running = false; networkPoller.running = true; running = false; running = true; } }

            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }


            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "h:mm AP");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            Loader {
                id: legacyBarVisuals
                anchors.fill: parent
                active: false
                sourceComponent: Component {
                    Item {
                        anchors.fill: parent
                        visible: false
                        enabled: false

                Rectangle {
                    id: leftContent
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight

                    color: "transparent"
                    radius: barWindow.s(5)
                    border.width: 0
                    border.color: "transparent"
                    clip: true
                    
                    property bool showLayout: false
                    
                    opacity: (showLayout && !barWindow.isSettingsOpen) ? 1 : 0
                    enabled: !barWindow.isSettingsOpen
                    
                    property real dockOffset: barWindow.s(8)
                    property real targetX: (showLayout && !barWindow.isSettingsOpen) ? -dockOffset : barWindow.s(-200)
                    x: targetX
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    
                    Timer {
                        running: barWindow.isStartupReady
                        interval: 10
                        onTriggered: leftContent.showLayout = true
                    }

                    width: leftLayout.width + barWindow.s(24)

                    Row {
                        id: leftLayout
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(8)
                        spacing: barWindow.s(7)
                        
                        property int pillHeight: barWindow.s(24)

                        Rectangle {
                            property bool isHovered: helpMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: barWindow.s(7)
                            
                            property real targetWidth: barWindow.showHelpIcon ? barWindow.s(36) : 0
                            width: targetWidth
                            height: parent.pillHeight
                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.showHelpIcon ? 1.0 : 0.0
                            clip: true
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰋗"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18)
                                color: parent.isHovered ? mocha.teal : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: helpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle guide"])
                            }
                        }

                        Rectangle {
                            property bool isHovered: searchMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.62) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.48)
                            radius: barWindow.s(6)
                            height: parent.pillHeight; width: barWindow.s(34)
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰍉"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(17)
                                color: parent.isHovered ? mocha.blue : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: searchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                            }
                        }

                        Rectangle {
                            id: bellPill
                            property bool isHovered: settingsMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.62) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.48)
                            radius: barWindow.s(6)
                            height: parent.pillHeight; width: barWindow.s(34)
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🔔"
                                font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(14)
                                color: parent.isHovered ? mocha.yellow : mocha.yellow
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }

                            Rectangle {
                                width: barWindow.s(7)
                                height: barWindow.s(7)
                                radius: width / 2
                                color: mocha.red
                                border.width: 1
                                border.color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.96)
                                anchors.top: parent.top
                                anchors.topMargin: barWindow.s(3)
                                anchors.right: parent.right
                                anchors.rightMargin: barWindow.s(3)
                            }

                            MouseArea {
                                id: settingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle notifications"])
                            }
                        }

                        Rectangle {
                            id: leftThemePill
                            property bool isHovered: leftThemeMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.62) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.48)
                            radius: barWindow.s(6)
                            height: parent.pillHeight
                            width: barWindow.s(34)

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰏘"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: barWindow.s(16)
                                color: parent.isHovered ? mocha.peach : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }

                            MouseArea {
                                id: leftThemeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle theme"])
                            }
                        }

                        Rectangle {
                            id: updateButton
                            property bool isHovered: updateMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.15) : "transparent"
                            radius: barWindow.s(10)
                            
                            width: barWindow.isUpdateVisible ? barWindow.s(34) : 0
                            height: parent.pillHeight
                            
                            visible: width > 0 || opacity > 0
                            opacity: barWindow.isUpdateVisible ? 1.0 : 0.0
                            clip: false 
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: parent.radius
                                color: mocha.green
                                z: -1
                                
                                SequentialAnimation on scale {
                                    running: barWindow.isUpdateVisible && !updateButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 1.3; duration: 2000; easing.type: Easing.OutCubic }
                                }
                                SequentialAnimation on opacity {
                                    running: barWindow.isUpdateVisible && !updateButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.15; to: 0.0; duration: 2000; easing.type: Easing.OutCubic }
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰚰"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.text : mocha.green
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                rotation: parent.isHovered ? 360 : 0
                                Behavior on rotation {
                                    NumberAnimation { 
                                        duration: 600
                                        easing.type: Easing.OutBack
                                    }
                                }

                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }

                            MouseArea {
                                id: updateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    barWindow.updateAvailable = false;
                                    barWindow.forceUpdateShow = false;
                                    Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle updater"]);
                                }
                            }
                        }
                    }
                }
                
                Rectangle {
                    id: workspacesBox
                    color: "transparent"
                    radius: barWindow.s(5); border.width: 0; border.color: "transparent"
                    height: barWindow.barHeight
                    y: (parent.height - barWindow.barHeight) / 2
                    clip: true
                    
                    width: workspacesModel.count > 0 ? wsLayout.implicitWidth + barWindow.s(10) : 0
                    
                    property real defaultX: leftContent.x + leftContent.width + barWindow.s(4)
                    property real settingsX: mediaBox.settingsX - width - (width > 0 ? barWindow.s(4) : 0)
                                        
                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    property bool limitActive: barWindow.isSettingsOpen && barWindow.isMediaActive

                    visible: width > 0 || opacity > 0
                    opacity: workspacesModel.count > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Rectangle {
                        id: activeHighlight
                        y: (workspacesBox.height - barWindow.s(24)) / 2
                        height: barWindow.s(24)
                        radius: barWindow.s(6)
                        color: mocha.mauve
                        z: 0

                        property int prevIdx: 0
                        property int curIdx: workspacesModel.activeIndex

                        onCurIdxChanged: {
                            if (curIdx > prevIdx) {
                                rightAnim.duration = 200; leftAnim.duration = 350;
                            } else if (curIdx < prevIdx) {
                                leftAnim.duration = 200; rightAnim.duration = 350;
                            }
                            prevIdx = curIdx;
                        }

                        // FIXED: Calculate step size to perfectly match the rounded width + rounded spacing of the Row elements.
                        property real stepSize: barWindow.s(28) + barWindow.s(7)
                        property real targetLeft: wsLayout.x + (curIdx * stepSize)
                        property real targetRight: targetLeft + barWindow.s(28)

                        property real actualLeft: targetLeft
                        property real actualRight: targetRight

                        Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                        x: actualLeft
                        width: actualRight - actualLeft
                        opacity: workspacesModel.count > 0 ? 1 : 0
                    }

                    Row {
                        id: wsLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(7)
                        
                        Repeater {
                            model: workspacesModel
                            delegate: Rectangle {
                                id: wsPill
                                
                                property bool isLimited: workspacesBox.limitActive && index >= 6
                                visible: !isLimited
                                
                                property bool isHovered: wsPillMouse.containsMouse
                                
                                property string stateLabel: model.wsState
                                property string wsName: model.wsId
                                
                                property real targetWidth: barWindow.s(28)
                                width: targetWidth
                                Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                
                                height: barWindow.s(24); radius: barWindow.s(6)
                                
                                color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.66) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.44)

                                scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                
                                property bool initAnimTrigger: false
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate {
                                    y: wsPill.initAnimTrigger ? 0 : barWindow.s(15)
                                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                }

                                Component.onCompleted: {
                                    if (!barWindow.startupCascadeFinished) {
                                        animTimer.interval = index * 60;
                                        animTimer.start();
                                    } else {
                                        initAnimTrigger = true;
                                    }
                                }

                                Timer {
                                    id: animTimer
                                    running: false
                                    repeat: false
                                    onTriggered: wsPill.initAnimTrigger = true
                                }
                                
                                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsName
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                    
                                    color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                                    
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }
                                MouseArea {
                                    id: wsPillMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: mediaBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    y: 0
                    height: barWindow.barHeight
                    clip: true

                    width: 0
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                    property real defaultX: workspacesBox.defaultX + workspacesBox.width + (workspacesBox.width > 0 ? barWindow.s(4) : 0)
                    property real settingsX: centerBox.settingsX - width - (width > 0 ? barWindow.s(4) : 0)

                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    visible: false  // media now shown inline in center notch pill
                    opacity: 0.0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                    
                    Item {
                        id: mediaLayoutContainer
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(12)
                        height: parent.height
                        width: innerMediaLayout.implicitWidth
                        
                        opacity: barWindow.isMediaActive ? 1.0 : 0.0
                        transform: Translate { 
                            x: barWindow.isMediaActive ? 0 : barWindow.s(-20) 
                            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        Row {
                            id: innerMediaLayout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.width < 1920 ? barWindow.s(8) : barWindow.s(16)
                            
                            MouseArea {
                                id: mediaInfoMouse
                                width: infoLayout.width
                                height: innerMediaLayout.height
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                                
                                Row {
                                    id: infoLayout
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(10)
                                    
                                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    Rectangle {
                                        width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(8); color: mocha.surface1
                                        border.width: barWindow.musicData.status === "Playing" ? 1 : 0
                                        border.color: mocha.mauve
                                        clip: true
                                        Image { 
                                            anchors.fill: parent; 
                                            source: barWindow.displayArtUrl || ""; 
                                            fillMode: Image.PreserveAspectCrop 
                                        }
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                        }
                                    }
                                    Column {
                                        spacing: -2
                                        anchors.verticalCenter: parent.verticalCenter
                                        property real maxColWidth: barWindow.width < 1920 ? barWindow.s(120) : barWindow.s(180)
                                        width: maxColWidth 
                                        
                                        Text { 
                                            text: barWindow.displayTitle; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(13); 
                                            color: mocha.text;
                                            width: parent.width
                                            elide: Text.ElideRight; 
                                        }
                                        Text { 
                                            text: barWindow.displayTime; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(10); 
                                            color: mocha.subtext0;
                                            width: parent.width
                                            elide: Text.ElideRight;
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.width < 1920 ? barWindow.s(4) : barWindow.s(8)
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: prevMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh prev"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(28); height: barWindow.s(28); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(30); 
                                        color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: playMouse.containsMouse ? 1.15 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh play-pause"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: nextMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh next"]); musicForceRefresh.running = true; } } 
                                }
                            }
                        }
                    }
                }

                // ── Notch (BoringNotch / Dynamic Island inspired) ────────────────
                // Hangs from the top of the bar: square top corners, rounded bottom.
                // Compact (time only) ⇄ Expanded (time · art · title · controls)
                // Expansion is driven by hover or active media — spring-animated width.
                Item {
                    id: centerBox

                    // Width state machine
                    property bool isHovered: notchHoverArea.containsMouse
                    property bool isPlaying: barWindow.musicData && barWindow.musicData.status === "Playing"
                    property bool wantsExpand: isHovered || barWindow.isMediaActive

                    property real compactWidth: barWindow.s(150)
                    property real expandedWidth: barWindow.s(460)
                    width: wantsExpand ? expandedWidth : compactWidth
                    Behavior on width {
                        SpringAnimation { spring: 2.4; damping: 0.32; epsilon: 0.5 }
                    }

                    // Anchored to the top of the bar — radius is on the inner Rectangle
                    y: 0
                    height: barWindow.barHeight

                    // Positioning preserved from previous notch so settings-slide animation keeps working.
                    property real pureCenter: (parent.width - width) / 2
                    property real minCenterDefaultX: mediaBox.defaultX + mediaBox.width + (mediaBox.width > 0 ? barWindow.s(4) : 0)
                    property real settingsX: barWindow.width - rightContent.width - width - barWindow.s(4)
                    property real defaultX: Math.max(minCenterDefaultX, pureCenter)
                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    // Startup drop-in animation
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        y: centerBox.showLayout ? 0 : barWindow.s(-30)
                        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    Timer { running: barWindow.isStartupReady; interval: 150; onTriggered: centerBox.showLayout = true }
                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // The hanging tab body — square top, rounded bottom.
                    Rectangle {
                        id: notchBody
                        anchors.fill: parent
                        color: "#11111b"
                        topLeftRadius: 0
                        topRightRadius: 0
                        bottomLeftRadius: barWindow.s(20)
                        bottomRightRadius: barWindow.s(20)
                        border.width: 0

                        // Hover wash — gentle purple tint, no scale (keeps edges crisp)
                        Rectangle {
                            anchors.fill: parent
                            topLeftRadius: 0
                            topRightRadius: 0
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius
                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, centerBox.isHovered ? 0.07 : 0)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }

                        // Inner highlight along the bottom curve — that subtle "Dynamic Island" glow
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: barWindow.s(2)
                            topLeftRadius: 0; topRightRadius: 0
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius
                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, centerBox.isPlaying ? 0.35 : 0.0)
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }

                    MouseArea {
                        id: notchHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                    }

                    // ── Content ────────────────────────────────────────────────
                    // Time is anchored hard-left so it never shifts; media content
                    // fades/slides in from the right as the notch expands.
                    Text {
                        id: notchTime
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: barWindow.s(18)
                        text: barWindow.timeStr
                        font.family: "JetBrains Mono"
                        font.pixelSize: barWindow.s(13)
                        font.weight: Font.Black
                        color: mocha.mauve
                    }

                    // Media cluster — only meaningful when something is playing,
                    // and visually revealed as the notch reaches expanded width.
                    Item {
                        id: notchMedia
                        anchors.left: notchTime.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: barWindow.s(10)
                        anchors.rightMargin: barWindow.s(14)
                        height: parent.height
                        clip: true

                        readonly property real revealThreshold: barWindow.s(260)
                        readonly property real reveal: Math.max(0, Math.min(1, (centerBox.width - revealThreshold) / barWindow.s(140)))
                        opacity: barWindow.isMediaActive ? reveal : 0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        visible: opacity > 0.01

                        // Separator bullet — sits between time and album art
                        Text {
                            id: notchDot
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "·"
                            color: mocha.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: barWindow.s(16)
                            font.weight: Font.Black
                        }

                        // Spinning circular album art with a thin mauve ring
                        Rectangle {
                            id: artRing
                            anchors.left: notchDot.right
                            anchors.leftMargin: barWindow.s(10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: barWindow.s(26); height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.40)

                            Rectangle {
                                id: artInner
                                anchors.centerIn: parent
                                width: parent.width - barWindow.s(4)
                                height: width
                                radius: width / 2
                                color: mocha.surface1
                                clip: true
                                antialiasing: true

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: barWindow.displayArtUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                // Slow vinyl-like rotation while playing
                                RotationAnimator on rotation {
                                    from: 0; to: 360
                                    duration: 14000
                                    loops: Animation.Infinite
                                    running: centerBox.isPlaying && artImg.status === Image.Ready
                                }
                            }

                            // Centered spindle dot, so it actually looks like spinning vinyl
                            Rectangle {
                                anchors.centerIn: parent
                                width: barWindow.s(4); height: width; radius: width / 2
                                color: mocha.base
                                opacity: 0.85
                            }
                        }

                        // Track title — elides cleanly between art and controls
                        Text {
                            id: notchTitle
                            anchors.left: artRing.right
                            anchors.right: notchControls.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: barWindow.s(10)
                            anchors.rightMargin: barWindow.s(10)
                            text: barWindow.displayTitle
                            color: mocha.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: barWindow.s(11)
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        // Transport controls — anchored to the right edge of the media area
                        Row {
                            id: notchControls
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.s(4)

                            Item {
                                width: barWindow.s(20); height: barWindow.s(20); anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(16)
                                    color: prevNotchMouse.containsMouse ? mocha.text : mocha.overlay2
                                    scale: prevNotchMouse.pressed ? 0.88 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: prevNotchMouse; hoverEnabled: true; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh prev"]) }
                            }
                            Item {
                                width: barWindow.s(22); height: barWindow.s(22); anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: centerBox.isPlaying ? "󰏤" : "󰐊"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(18)
                                    color: playNotchMouse.containsMouse ? mocha.green : mocha.text
                                    scale: playNotchMouse.pressed ? 0.88 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: playNotchMouse; hoverEnabled: true; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh play-pause"]) }
                            }
                            Item {
                                width: barWindow.s(20); height: barWindow.s(20); anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(16)
                                    color: nextNotchMouse.containsMouse ? mocha.text : mocha.overlay2
                                    scale: nextNotchMouse.pressed ? 0.88 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                }
                                MouseArea { id: nextNotchMouse; hoverEnabled: true; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh next"]) }
                            }
                        }
                    }
                }

                    Row {
                        id: rightContent
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: -barWindow.s(8)
                        spacing: barWindow.s(4)
                    
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        x: rightContent.showLayout ? 0 : barWindow.s(30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: barWindow.isStartupReady && barWindow.isDataReady
                        interval: 250
                        onTriggered: rightContent.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    Rectangle {
                        height: barWindow.barHeight
                        radius: barWindow.s(14)
                        border.color: "transparent"
                        border.width: 0
                        color: "transparent"
                        
                        property real targetWidth: 0
                        width: targetWidth
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                        
                        visible: targetWidth > 0
                        opacity: targetWidth > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Row {
                            id: trayLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)

                            Repeater {
                                id: trayRepeater
                                model: SystemTray.items
                                delegate: Image {
                                    id: trayIcon
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    
                                    sourceSize: Qt.size(barWindow.s(18), barWindow.s(18))
                                    width: barWindow.s(18)
                                    height: barWindow.s(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    property bool isHovered: trayMouse.containsMouse
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                    scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            trayAnimTimer.interval = index * 50;
                                            trayAnimTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }
                                    Timer {
                                        id: trayAnimTimer
                                        running: false
                                        repeat: false
                                        onTriggered: trayIcon.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.activate === "function") {
                                                    modelData.activate(); 
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                if (typeof modelData.secondaryActivate === "function") {
                                                    modelData.secondaryActivate();
                                                }
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (modelData.menu) { 
                                                    menuAnchor.open();
                                                } else if (typeof modelData.contextMenu === "function") {
                                                    modelData.contextMenu(mouse.x, mouse.y);
                                                } else {
                                                    modelData.activate(); 
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        height: barWindow.barHeight
                        radius: barWindow.s(8)
                        border.color: "transparent"
                        border.width: 0
                        color: "transparent"
                        clip: false
                        
                        width: sysLayout.implicitWidth + barWindow.s(20)

                        Row {
                            id: sysLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(7) 

                            property int pillHeight: barWindow.s(24)

                            Rectangle {
                                id: kbPill
                                property bool isHovered: kbMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: barWindow.s(6); height: sysLayout.pillHeight;
                                clip: true
                                
                                property real targetWidth: 0
                                width: targetWidth
                                visible: targetWidth > 0
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !kbPill.initAnimTrigger; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: kbPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: kbLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: parent.parent.isHovered ? mocha.text : mocha.overlay2 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.kbLayout; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.text }
                                }
                                MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]) }
                            }

                            Rectangle {
                                id: wifiPill
                                property bool isHovered: wifiMouse.containsMouse
                                radius: barWindow.s(6); height: sysLayout.pillHeight; 
                                color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.64) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.46)
                                clip: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(6)
                                    opacity: 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.blue }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                                    }
                                }

                                property real targetWidth: barWindow.showEthernet ? barWindow.s(116) : wifiLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !wifiPill.initAnimTrigger; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: wifiLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(7)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter; 
                                        text: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon;
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16);
                                        color: mocha.blue
                                    }
                                    Text { 
                                        id: wifiText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.showEthernet ? barWindow.ethStatus : ((barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"))
                                        visible: text !== ""
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: mocha.text;
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", barWindow.showEthernet ? "~/.config/hypr/scripts/qs_manager.sh toggle ethernet" : "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
                            }

                            Rectangle {
                                id: btPill
                                property bool isHovered: btMouse.containsMouse
                                radius: barWindow.s(6); height: sysLayout.pillHeight
                                clip: true
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(6)
                                    opacity: barWindow.isBtOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.mauve }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                    }
                                }

                                property real targetWidth: barWindow.isDesktop ? 0 : btLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                visible: targetWidth > 0
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !btPill.initAnimTrigger; interval: 100; onTriggered: btPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: btPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: btLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: barWindow.isBtOn ? mocha.base : mocha.subtext0 }
                                    Text { 
                                        id: btText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.btDevice
                                        visible: text !== ""; 
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                        color: barWindow.isBtOn ? mocha.base : mocha.text; 
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"]) }
                            }

                            Rectangle {
                                id: volPill
                                property bool isHovered: volMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.64) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.46)
                                radius: barWindow.s(6); height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(6)
                                    opacity: 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.peach }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                                    }
                                }
                                
                                property real targetWidth: volLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !volPill.initAnimTrigger; interval: 150; onTriggered: volPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: volPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: volLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(7)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); 
                                        color: mocha.subtext0 
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volPercent; 
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                        color: mocha.text;
                                    }
                                }
                                MouseArea { id: volMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"]) }
                            }

                            // Theme picker button
                            Rectangle {
                                id: themeBtn
                                visible: false
                                property bool isHovered: themeBtnMouse.containsMouse
                                height: sysLayout.pillHeight; radius: barWindow.s(6)
                                color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.64) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.46)
                                width: 0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Row {
                                    id: themeBtnRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "🎨"; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); color: themeBtn.isHovered ? mocha.mauve : mocha.overlay2; Behavior on color { ColorAnimation { duration: 150 } } }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Theme"; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(12); font.weight: Font.Bold; color: themeBtn.isHovered ? mocha.text : mocha.text; Behavior on color { ColorAnimation { duration: 150 } } }
                                }
                                MouseArea { id: themeBtnMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle theme"]) }
                            }

                            // Quick Settings button
                            Rectangle {
                                id: qsBtn
                                property bool isHovered: qsBtnMouse.containsMouse
                                height: sysLayout.pillHeight; radius: barWindow.s(6)
                                color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.64) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.46)
                                width: qsBtnRow.implicitWidth + barWindow.s(20)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Row {
                                    id: qsBtnRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "⊞"; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(16); color: qsBtn.isHovered ? mocha.mauve : mocha.overlay2; Behavior on color { ColorAnimation { duration: 150 } } }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Quick Settings"; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(12); font.weight: Font.Bold; color: qsBtn.isHovered ? mocha.text : mocha.text; Behavior on color { ColorAnimation { duration: 150 } } }
                                }
                                MouseArea { id: qsBtnMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle quicksettings"]) }
                            }

                        }
            }
            Rectangle {
                        id: recButton
                        property bool isHovered: recMouse.containsMouse
                        
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)

                        property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                        width: targetWidth
                        height: barWindow.barHeight 

                        visible: targetWidth > 0 || opacity > 0
                        opacity: barWindow.isRecording ? 1.0 : 0.0
                        clip: true

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            id: recIcon
                            anchors.centerIn: parent
                            text: "" 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: barWindow.s(20)
                            color: mocha.red
                            
                            SequentialAnimation on opacity {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on scale {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                barWindow.isRecording = false; 
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]); 
                            }
                        }
                    }
                }
                    }
                }
            }

                Item {
                    id: rebuiltBar
                    anchors.fill: parent

                    property real edgeClip: barWindow.s(24)
                    property real islandHeight: barWindow.barHeight
                    property real innerHeight: 22
                    property real islandRadius: barWindow.s(14)
                    property real islandUnifiedWidth: 450
                    property color islandColor: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.96)
                    property color islandBorder: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.38)
                    property color chipColor: Qt.rgba(68 / 255, 71 / 255, 90 / 255, 0.94)
                    property color chipHover: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.94)
                    property color notchBlack: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.96)

                    Rectangle {
                        id: rebuiltLeftIsland
                        x: -rebuiltBar.edgeClip
                        y: -2
                        height: rebuiltBar.islandHeight + 2
                        width: barWindow.s(260)
                        topLeftRadius: 0
                        bottomLeftRadius: 0
                        topRightRadius: 0
                        bottomRightRadius: rebuiltBar.islandRadius
                        color: rebuiltBar.islandColor
                        border.width: 0
                        border.color: rebuiltBar.islandBorder
                        clip: true

                        property bool shown: false
                        opacity: shown && !barWindow.isSettingsOpen ? 1 : 0
                        transform: Translate {
                            x: rebuiltLeftIsland.shown ? 0 : -barWindow.s(48)
                            Behavior on x { NumberAnimation { duration: 650; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }

                        Timer {
                            running: barWindow.isStartupReady
                            interval: 20
                            onTriggered: rebuiltLeftIsland.shown = true
                        }

                        Row {
                            id: rebuiltLeftRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            anchors.left: parent.left
                            anchors.leftMargin: rebuiltBar.edgeClip + barWindow.s(8)
                            spacing: barWindow.s(6)

                            Item {
                                width: rebuiltWorkspaceStack.implicitWidth
                                height: rebuiltBar.innerHeight
                                clip: true
                                visible: true

                                Rectangle {
                                    id: rebuiltWorkspaceHighlight
                                    x: barWindow.s((32 + 6) * (workspacesModel.count > 0 ? workspacesModel.activeIndex : 0))
                                    y: 0
                                    width: barWindow.s(32)
                                    height: rebuiltBar.innerHeight
                                    radius: barWindow.s(9)
                                    color: mocha.mauve
                                    opacity: 1
                                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                                    Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }
                                }

                                Row {
                                    id: rebuiltWorkspaceStack
                                    spacing: barWindow.s(6)

                                    Repeater {
                                        model: workspacesModel.count > 0 ? workspacesModel : barWindow.workspaceCount
                                        delegate: Rectangle {
                                            property string fallbackWsName: (index + 1).toString()
                                            property string resolvedWsName: workspacesModel.count > 0 ? model.wsId : fallbackWsName
                                            property string resolvedWsState: workspacesModel.count > 0 ? model.wsState : (index === 0 ? "active" : "")
                                            property bool resolvedActive: workspacesModel.count > 0 ? index === workspacesModel.activeIndex : index === 0

                                            width: barWindow.s(32)
                                            height: rebuiltBar.innerHeight
                                            radius: barWindow.s(9)
                                            color: rebuiltWorkspaceMouse.containsMouse ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.50) : "transparent"
                                            scale: rebuiltWorkspaceMouse.containsMouse && !resolvedActive ? 1.06 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: 180 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: resolvedWsName
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: barWindow.s(13)
                                                font.weight: resolvedActive ? Font.Black : Font.Bold
                                                color: resolvedActive ? mocha.crust : (resolvedWsState === "occupied" ? mocha.text : mocha.overlay0)
                                                Behavior on color { ColorAnimation { duration: 240 } }
                                            }
                                            MouseArea {
                                                id: rebuiltWorkspaceMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + resolvedWsName])
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: rebuiltSearch
                                width: barWindow.s(38)
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                color: rebuiltSearchMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltSearchMouse.containsMouse ? 1.06 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍉"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(18)
                                    color: rebuiltSearchMouse.containsMouse ? mocha.blue : mocha.subtext0
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                MouseArea {
                                    id: rebuiltSearchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                                }
                            }

                            Rectangle {
                                id: rebuiltBell
                                width: barWindow.s(38)
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                color: rebuiltBellMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltBellMouse.containsMouse ? 1.06 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(18)
                                    color: rebuiltBellMouse.containsMouse ? mocha.yellow : mocha.subtext0
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Rectangle {
                                    width: barWindow.s(6)
                                    height: width
                                    radius: width / 2
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: barWindow.s(4)
                                    anchors.rightMargin: barWindow.s(4)
                                    color: mocha.red
                                }
                                MouseArea {
                                    id: rebuiltBellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle notifications"])
                                }
                            }

                            Rectangle {
                                id: rebuiltLeftTheme
                                width: barWindow.s(38)
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                color: rebuiltLeftThemeMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltLeftThemeMouse.containsMouse ? 1.06 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏘"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(17)
                                    color: rebuiltLeftThemeMouse.containsMouse ? mocha.peach : mocha.subtext0
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                MouseArea {
                                    id: rebuiltLeftThemeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle theme"])
                                }
                            }

                            Rectangle {
                                width: barWindow.isUpdateVisible ? barWindow.s(38) : 0
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                visible: width > 0 || opacity > 0
                                opacity: barWindow.isUpdateVisible ? 1 : 0
                                color: rebuiltUpdateMouse.containsMouse ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.24) : Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.12)
                                clip: true
                                Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰚰"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(20)
                                    color: mocha.green
                                }
                                MouseArea {
                                    id: rebuiltUpdateMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        barWindow.updateAvailable = false;
                                        barWindow.forceUpdateShow = false;
                                        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle updater"]);
                                    }
                                }
                            }
                        }
                    }

                    // Centered time island — shown only when no media is playing.
                    // When media plays, the BoringNotch overlay owns the center and the
                    // right-island time chip takes over.
                    Rectangle {
                        id: rebuiltCenterIsland
                        readonly property bool hasMedia: !!(barWindow.musicData && barWindow.musicData.title && barWindow.musicData.title !== "" && barWindow.musicData.status === "Playing")
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -2
                        height: rebuiltBar.islandHeight + 2
                        width: rebuiltCenterTimeChip.width + barWindow.s(16)
                        topLeftRadius: 0
                        topRightRadius: 0
                        bottomLeftRadius: rebuiltBar.islandRadius
                        bottomRightRadius: rebuiltBar.islandRadius
                        color: rebuiltBar.islandColor
                        border.width: 0
                        border.color: rebuiltBar.islandBorder
                        clip: true

                        property bool shown: false
                        visible: opacity > 0.01
                        opacity: (shown && !hasMedia) ? 1 : 0
                        transform: Translate {
                            y: rebuiltCenterIsland.shown ? 0 : -barWindow.s(48)
                            Behavior on y { NumberAnimation { duration: 650; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }

                        Timer {
                            running: barWindow.isStartupReady
                            interval: 100
                            onTriggered: rebuiltCenterIsland.shown = true
                        }

                        Rectangle {
                            id: rebuiltCenterTimeChip
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            height: rebuiltBar.innerHeight
                            width: rebuiltCenterTimeRow.implicitWidth + barWindow.s(22)
                            radius: barWindow.s(9)
                            color: rebuiltCenterTimeMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                            Behavior on color { ColorAnimation { duration: 180 } }
                            scale: rebuiltCenterTimeMouse.containsMouse ? 1.04 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                            Row {
                                id: rebuiltCenterTimeRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(6)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰥔"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(15)
                                    color: mocha.mauve
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.timeStr
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Black
                                    color: mocha.text
                                }
                            }
                            MouseArea {
                                id: rebuiltCenterTimeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                            }
                        }
                    }

                    // ── BoringNotch / Dynamic Island ───────────────────────────────
                    // Hangs from the screen-top edge. The element is taller than it shows
                    // (top half clipped above bar) so radius 30 forms a smooth bottom curve
                    // and a perfectly flat top edge. Three states: compact (time), hover,
                    // and media. Hover expands fully when nothing is playing.
                    Rectangle {
                        id: rebuiltCenterNotch
                        anchors.horizontalCenter: parent.horizontalCenter

                        // disabled — standalone BoringNotch.qml owns this surface now
                        visible: false
                        enabled: false

                        property bool isHovered: rebuiltCenterMouse.containsMouse
                        property bool isPlaying: barWindow.musicData && barWindow.musicData.status === "Playing"
                        property bool wantsExpand: isHovered || barWindow.isMediaActive

                        // Compact silhouette is intentionally small to make the expansion feel like
                        // it's "blooming" out of the screen edge.
                        property real compactWidth: barWindow.s(160)
                        property real expandedWidth: barWindow.s(560)
                        width: wantsExpand ? expandedWidth : compactWidth
                        Behavior on width { SpringAnimation { spring: 2.4; damping: 0.30; epsilon: 0.5 } }

                        // Anchored above the bar; only the bottom barHeight is visible,
                        // which clips the top corners flat — the hanging-tab look.
                        y: barWindow.s(-40)
                        height: barWindow.s(82)
                        radius: barWindow.s(30)
                        color: rebuiltBar.notchBlack
                        border.width: 1.4
                        border.color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, isHovered ? 0.55 : (isPlaying ? 0.32 : 0.16))
                        clip: true

                        property bool shown: false
                        opacity: shown ? 1 : 0
                        // Slightly stronger hover lift so it feels tactile (compared to old 1.012)
                        scale: isHovered ? 1.025 : 1.0
                        transform: Translate {
                            y: rebuiltCenterNotch.shown ? 0 : -barWindow.s(40)
                            Behavior on y { NumberAnimation { duration: 760; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                        Behavior on border.color { ColorAnimation { duration: 360; easing.type: Easing.InOutCubic } }

                        Timer { running: barWindow.isStartupReady; interval: 120; onTriggered: rebuiltCenterNotch.shown = true }

                        MouseArea {
                            id: rebuiltCenterMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Click does nothing — popup is hover-driven only.
                        }

                        // Hover-to-open: sustained hover for ~380 ms opens the music panel.
                        Timer {
                            id: notchHoverOpenTimer
                            interval: 380
                            running: rebuiltCenterNotch.isHovered && barWindow.activeWidget !== "music"
                            repeat: false
                            onTriggered: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh open music"])
                        }

                        // Hover-to-close: when neither the notch nor the popup is hovered,
                        // close after a short grace. The popup writes /run/qs/popup_hover
                        // while it's hovered so transit notch→popup doesn't dismiss it.
                        Timer {
                            id: notchHoverCloseTimer
                            interval: 420
                            running: !rebuiltCenterNotch.isHovered && barWindow.activeWidget === "music"
                            repeat: false
                            onTriggered: Quickshell.execDetached([
                                "bash", "-c",
                                "[ -f " + paths.runDir + "/popup_hover ] || ~/.config/hypr/scripts/qs_manager.sh close music"
                            ])
                        }

                        // Hover wash — gentle mauve tint, fades on top of the body
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, rebuiltCenterNotch.isHovered ? 0.06 : 0)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }

                        // Bottom accent — present always, brightens & pulses while playing.
                        // Sits flush against the bottom interior edge; the curve crops it cleanly.
                        Rectangle {
                            id: notchAccent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: barWindow.s(22)
                            anchors.rightMargin: barWindow.s(22)
                            anchors.bottomMargin: barWindow.s(3)
                            height: barWindow.s(2)
                            radius: height / 2
                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b,
                                rebuiltCenterNotch.isPlaying ? 0.85 : (rebuiltCenterNotch.isHovered ? 0.35 : 0.10))
                            Behavior on color { ColorAnimation { duration: 380 } }

                            SequentialAnimation on opacity {
                                running: rebuiltCenterNotch.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.55; to: 1.0; duration: 1100; easing.type: Easing.InOutCubic }
                                NumberAnimation { from: 1.0; to: 0.55; duration: 1100; easing.type: Easing.InOutCubic }
                            }
                        }

                        // Content area — restricted to the visible bottom strip
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: barWindow.barHeight

                            // Time — re-anchors based on state. Centers when compact, snaps left when expanded.
                            Text {
                                id: rebuiltCenterTime
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: rebuiltCenterNotch.wantsExpand ? undefined : parent.horizontalCenter
                                anchors.left: rebuiltCenterNotch.wantsExpand ? parent.left : undefined
                                anchors.leftMargin: barWindow.s(24)
                                text: barWindow.timeStr
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(13)
                                font.weight: Font.Black
                                color: mocha.mauve
                                Behavior on color { ColorAnimation { duration: 360; easing.type: Easing.InOutCubic } }
                            }

                            // Media cluster — fades in only as the notch crosses a width threshold,
                            // so no janky pop-in mid-spring.
                            Item {
                                id: rebuiltMediaCluster
                                anchors.left: rebuiltCenterTime.right
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: barWindow.s(14)
                                anchors.rightMargin: barWindow.s(22)
                                height: parent.height

                                readonly property real reveal: Math.max(0, Math.min(1, (rebuiltCenterNotch.width - barWindow.s(320)) / barWindow.s(160)))
                                opacity: barWindow.isMediaActive ? reveal : 0
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                                Text {
                                    id: rebuiltBullet
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "·"
                                    color: mocha.subtext0
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(16)
                                    font.weight: Font.Black
                                }

                                // Spinning vinyl-style album art with thin mauve halo + center spindle.
                                Rectangle {
                                    id: rebuiltArtHalo
                                    anchors.left: rebuiltBullet.right
                                    anchors.leftMargin: barWindow.s(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: barWindow.s(26); height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.45)

                                    Rectangle {
                                        id: rebuiltArtDisc
                                        anchors.centerIn: parent
                                        width: parent.width - barWindow.s(4); height: width
                                        radius: width / 2
                                        color: mocha.surface1
                                        clip: true
                                        antialiasing: true

                                        Image {
                                            id: rebuiltArtImg
                                            anchors.fill: parent
                                            source: (barWindow.isMediaActive && barWindow.displayArtUrl !== "" && barWindow.displayArtUrl.indexOf("/covers/placeholder_blank.png") === -1) ? barWindow.displayArtUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            asynchronous: true
                                        }

                                        RotationAnimator on rotation {
                                            from: 0; to: 360
                                            duration: 14000
                                            loops: Animation.Infinite
                                            running: rebuiltCenterNotch.isPlaying && rebuiltArtImg.status === Image.Ready
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: barWindow.s(4); height: width; radius: width / 2
                                        color: rebuiltBar.notchBlack
                                        opacity: 0.92
                                    }
                                }

                                Text {
                                    id: rebuiltTrackTitle
                                    anchors.left: rebuiltArtHalo.right
                                    anchors.right: rebuiltCenterControls.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: barWindow.s(10)
                                    anchors.rightMargin: barWindow.s(10)
                                    text: barWindow.displayTitle
                                    color: mocha.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(11)
                                    font.weight: Font.Black
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 360 } }
                                }

                                Row {
                                    id: rebuiltCenterControls
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(4)

                                    Item {
                                        width: barWindow.s(22); height: width; anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent; text: "󰒮"
                                            font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18)
                                            color: rebuiltPrevMouse.containsMouse ? mocha.text : mocha.overlay2
                                            scale: rebuiltPrevMouse.pressed ? 0.85 : 1.0
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea {
                                            id: rebuiltPrevMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh prev"]);
                                                musicForceRefresh.running = true;
                                            }
                                        }
                                    }
                                    Item {
                                        width: barWindow.s(26); height: width; anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: rebuiltCenterNotch.isPlaying ? "󰏤" : "󰐊"
                                            font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                            color: rebuiltPlayMouse.containsMouse ? mocha.green : mocha.text
                                            scale: rebuiltPlayMouse.pressed ? 0.85 : 1.0
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea {
                                            id: rebuiltPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh play-pause"]);
                                                musicForceRefresh.running = true;
                                            }
                                        }
                                    }
                                    Item {
                                        width: barWindow.s(22); height: width; anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent; text: "󰒭"
                                            font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18)
                                            color: rebuiltNextMouse.containsMouse ? mocha.text : mocha.overlay2
                                            scale: rebuiltNextMouse.pressed ? 0.85 : 1.0
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea {
                                            id: rebuiltNextMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/music/player_control.sh next"]);
                                                musicForceRefresh.running = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: rebuiltRightIsland
                        anchors.right: parent.right
                        anchors.rightMargin: -rebuiltBar.edgeClip
                        y: -2
                        height: rebuiltBar.islandHeight + 2
                        width: rebuiltRightRow.implicitWidth + rebuiltBar.edgeClip + barWindow.s(16)
                        topLeftRadius: 0
                        bottomLeftRadius: rebuiltBar.islandRadius
                        topRightRadius: 0
                        bottomRightRadius: 0
                        color: rebuiltBar.islandColor
                        border.width: 0
                        border.color: rebuiltBar.islandBorder
                        clip: true

                        property bool shown: false
                        opacity: shown ? 1 : 0
                        transform: Translate {
                            x: rebuiltRightIsland.shown ? 0 : barWindow.s(48)
                            Behavior on x { NumberAnimation { duration: 650; easing.type: Easing.OutExpo } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 520; easing.type: Easing.InOutCubic } }

                        Timer {
                            running: barWindow.isStartupReady && barWindow.isDataReady
                            interval: 180
                            onTriggered: rebuiltRightIsland.shown = true
                        }

                        Row {
                            id: rebuiltRightRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            anchors.right: parent.right
                            anchors.rightMargin: rebuiltBar.edgeClip + barWindow.s(8)
                            spacing: barWindow.s(6)

                            Rectangle {
                                id: rebuiltRecording
                                width: barWindow.isRecording ? barWindow.s(38) : 0
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                visible: width > 0 || opacity > 0
                                opacity: barWindow.isRecording ? 1 : 0
                                color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, rebuiltRecMouse.containsMouse ? 0.24 : 0.14)
                                clip: true
                                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(18)
                                    color: mocha.red
                                    SequentialAnimation on opacity {
                                        running: barWindow.isRecording
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                                    }
                                }
                                MouseArea {
                                    id: rebuiltRecMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        barWindow.isRecording = false;
                                        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]);
                                    }
                                }
                            }

                            Rectangle {
                                id: rebuiltWifi
                                height: rebuiltBar.innerHeight
                                width: barWindow.showEthernet ? barWindow.s(116) : rebuiltWifiRow.implicitWidth + barWindow.s(22)
                                radius: barWindow.s(9)
                                color: rebuiltWifiMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltWifiMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Row {
                                    id: rebuiltWifiRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(16)
                                        color: mocha.blue
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.showEthernet ? barWindow.ethStatus : ((barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"))
                                        width: Math.min(implicitWidth, barWindow.s(92))
                                        elide: Text.ElideRight
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: Font.Black
                                        color: mocha.text
                                    }
                                }
                                MouseArea {
                                    id: rebuiltWifiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", barWindow.showEthernet ? "~/.config/hypr/scripts/qs_manager.sh toggle ethernet" : "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"])
                                }
                            }

                            Rectangle {
                                id: rebuiltVolume
                                height: rebuiltBar.innerHeight
                                width: rebuiltVolumeRow.implicitWidth + barWindow.s(22)
                                radius: barWindow.s(9)
                                color: rebuiltVolumeMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltVolumeMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Row {
                                    id: rebuiltVolumeRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volIcon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(16)
                                        color: mocha.subtext0
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volPercent
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: Font.Black
                                        color: mocha.text
                                    }
                                }
                                MouseArea {
                                    id: rebuiltVolumeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"])
                                }
                            }

                            Rectangle {
                                id: rebuiltTheme
                                visible: false
                                height: rebuiltBar.innerHeight
                                width: 0
                                radius: barWindow.s(9)
                                color: rebuiltThemeMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltThemeMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Row {
                                    id: rebuiltThemeRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰏘"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(16)
                                        color: mocha.peach
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Theme"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: Font.Black
                                        color: mocha.text
                                    }
                                }
                                MouseArea {
                                    id: rebuiltThemeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle theme"])
                                }
                            }

                            Rectangle {
                                id: rebuiltQuickSettings
                                height: rebuiltBar.innerHeight
                                width: rebuiltQsRow.implicitWidth + barWindow.s(22)
                                radius: barWindow.s(9)
                                color: rebuiltQsMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltQsMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Row {
                                    id: rebuiltQsRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰒓"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(16)
                                        color: mocha.overlay2
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Quick Settings"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: Font.Black
                                        color: mocha.text
                                    }
                                }
                                MouseArea {
                                    id: rebuiltQsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle quicksettings"])
                                }
                            }

                            // Time chip — only shown when media is playing. When idle, BoringNotch shows the time centered.
                            Rectangle {
                                id: rebuiltTimeChip
                                readonly property bool hasMedia: !!(barWindow.musicData && barWindow.musicData.title && barWindow.musicData.title !== "" && barWindow.musicData.status === "Playing")
                                height: rebuiltBar.innerHeight
                                radius: barWindow.s(9)
                                visible: width > 1 || opacity > 0.01
                                clip: true
                                color: rebuiltTimeMouse.containsMouse ? rebuiltBar.chipHover : rebuiltBar.chipColor
                                Behavior on color { ColorAnimation { duration: 180 } }
                                scale: rebuiltTimeMouse.containsMouse ? 1.04 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                property real targetWidth: rebuiltTimeRow.implicitWidth + barWindow.s(22)
                                width: hasMedia ? targetWidth : 0
                                opacity: hasMedia ? 1 : 0
                                Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                                Row {
                                    id: rebuiltTimeRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰥔"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(15)
                                        color: mocha.mauve
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.timeStr
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: Font.Black
                                        color: mocha.text
                                    }
                                }
                                MouseArea {
                                    id: rebuiltTimeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                                }
                            }
                        }
                    }
                }
        }
    }
}

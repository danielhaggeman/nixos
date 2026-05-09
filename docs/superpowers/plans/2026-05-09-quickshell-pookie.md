# Quickshell Pookie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port ilyamiro/nixos-configuration's Quickshell desktop shell to Daniel's NixOS/Hyprland setup — Dracula-themed, desktop-only (no battery), with a BoringNotch center pill, customizable quick settings, 5 themes, Alacritty terminal, and fastfetch config.

**Architecture:** Download all QML + shell scripts from the source repo into `~/dotfiles/quickshell/`, make targeted adaptations (Catppuccin→Dracula colors, battery removal, BoringNotch pill, theme picker), symlink to `~/.config/quickshell/`, and autostart via Hyprland. Alacritty and fastfetch configs live in `~/dotfiles/alacritty/` and `~/dotfiles/fastfetch/`.

**Tech Stack:** Quickshell (QML/Qt), Bash shell scripts, Python 3, nmcli, playerctl, matugen, EasyEffects, wl-clipboard, NixOS/nixpkgs.

---

## File Map

```
~/dotfiles/quickshell/          → symlink: ~/.config/quickshell/
  Shell.qml                     entry point (ShellRoot)
  Main.qml                      top-level component
  Config.qml                    singleton: paths, settings, JSON persistence
  TopBar.qml                    bar (battery stripped, notch added)
  MatugenColors.qml             color singleton (Catppuccin→Dracula)
  Floating.qml                  floating windows container
  Lock.qml                      lock screen
  ScreenshotOverlay.qml         screenshot capture
  SysData.qml                   system data (CPU/RAM/net)
  Scaler.qml                    DPI/scale helper
  Caching.qml                   wallpaper cache
  WindowRegistry.js             window management helpers
  applauncher/
    appLauncher.qml             search/launcher overlay
    app_fetcher.py              app list fetcher
  music/
    MusicPopup.qml              album art + EQ panel
    music_info.sh               playerctl MPRIS poller
    player_control.sh           play/pause/next/prev
    equalizer.sh                easyeffects preset loader
  calendar/
    CalendarPopup.qml           clock + weather + calendar
    weather.sh                  OpenWeatherMap fetcher
    diary_manager.sh            diary file manager
    schedule/
      get_schedule.py           schedule parser
      schedule_manager.sh       schedule runner
  network/
    NetworkPopup.qml            wifi + bluetooth popup
    wifi_panel_logic.sh         nmcli wifi commands
    bluetooth_panel_logic.sh    bluetoothctl commands
    eth_panel_logic.sh          nmcli ethernet + IP edit commands (NEW)
  notifications/
    NotificationPopups.qml      notification cards
  volume/
    VolumePopup.qml             audio device + slider
    audio_control.sh            pamixer/pactl commands
    get_audio_state.py          audio state reader
  wallpaper/
    WallpaperPicker.qml         DDG search + wallpaper setter
    ddg_search.sh               DuckDuckGo image search
    get_ddg_links.py            DDG link extractor
    matugen_reload.sh           runs matugen on new wallpaper
  focustime/
    FocusTimePopup.qml          daily app usage stats
    focus_daemon.py             usage tracker daemon
    get_stats.py                stats reader
    launch_daemon.sh            daemon launcher
  clipboard/
    ClipboardManager.qml        clipboard history panel
    clip_fetcher.py             wl-paste history reader
  quickactions/
    DrawAction.qml              annotation overlay
    SystemUsage.qml             CPU/RAM/GPU live view
    Timer.qml                   countdown timer
  monitors/
    MonitorPopup.qml            display config
  settings/
    SettingsPopup.qml           keybinds + startup + display + theme picker
  updater/
    UpdaterPopup.qml            system update checker
  stewart/
    stewart.qml                 AI assistant widget
  guide/
    GuidePopup.qml              help popup
  watchers/
    audio_fetch.sh / audio_wait.sh
    bt_fetch.sh / bt_wait.sh
    kb_fetch.sh / kb_wait.sh
    network_fetch.sh / network_wait.sh
    sys_fetcher.sh
    # battery_fetch.sh + battery_wait.sh → NOT downloaded

~/dotfiles/alacritty/
  alacritty.toml                terminal config

~/dotfiles/fastfetch/
  config.jsonc                  fastfetch layout + colors

~/dotfiles/nixos/configuration.nix    add alacritty, matugen, hyprlock; remove waybar
~/dotfiles/hypr/configs/autostart.conf  remove waybar/eww, add quickshell
```

---

## Task 1: NixOS packages

**Files:**
- Modify: `~/dotfiles/nixos/configuration.nix`

- [ ] **Add alacritty, matugen, hyprlock; remove waybar and eww from packages**

Open `~/dotfiles/nixos/configuration.nix`. In the `environment.systemPackages` block:

Remove these lines:
```nix
    waybar
    eww
```

Add these lines (anywhere in the block):
```nix
    alacritty
    matugen
    hyprlock
```

- [ ] **Rebuild NixOS**

```bash
sudo nixos-rebuild switch
```

Expected: rebuild completes, `which alacritty` returns a path, `which matugen` returns a path.

- [ ] **Verify**

```bash
which alacritty && which matugen && which hyprlock
```

Expected: three paths printed, no "not found".

- [ ] **Commit**

```bash
cd ~/dotfiles
git add nixos/configuration.nix
git commit -m "feat: add alacritty, matugen, hyprlock; remove waybar and eww packages"
```

---

## Task 2: Create quickshell directory and symlink

**Files:**
- Create: `~/dotfiles/quickshell/` (directory)
- Create: `~/.config/quickshell` (symlink)

- [ ] **Create directory and symlink**

```bash
mkdir -p ~/dotfiles/quickshell
ln -sf ~/dotfiles/quickshell ~/.config/quickshell
```

- [ ] **Verify symlink**

```bash
ls -la ~/.config/quickshell
```

Expected: `~/.config/quickshell -> /home/daniel/dotfiles/quickshell`

---

## Task 3: Download all source QML and scripts

**Files:** All files under `~/dotfiles/quickshell/`

The source repo is `ilyamiro/nixos-configuration`. All quickshell files live under `config/sessions/hyprland/scripts/quickshell/` in that repo. Raw URL base: `https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell`

- [ ] **Create subdirectories**

```bash
mkdir -p ~/dotfiles/quickshell/{applauncher,music,calendar/schedule,network,notifications,volume,wallpaper,focustime,clipboard,quickactions,monitors,settings,updater,stewart,guide,watchers}
```

- [ ] **Download core QML files**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
cd ~/dotfiles/quickshell

for f in Shell.qml Main.qml Config.qml TopBar.qml MatugenColors.qml Floating.qml Lock.qml ScreenshotOverlay.qml SysData.qml Scaler.qml Caching.qml WindowRegistry.js; do
  curl -sL "$BASE/$f" -o "$f"
  echo "Downloaded $f"
done
```

Expected: 12 files downloaded, each echoed.

- [ ] **Download applauncher**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
curl -sL "$BASE/applauncher/appLauncher.qml" -o ~/dotfiles/quickshell/applauncher/appLauncher.qml
curl -sL "$BASE/applauncher/app_fetcher.py" -o ~/dotfiles/quickshell/applauncher/app_fetcher.py
```

- [ ] **Download music**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
for f in MusicPopup.qml music_info.sh player_control.sh equalizer.sh; do
  curl -sL "$BASE/music/$f" -o ~/dotfiles/quickshell/music/$f
done
```

- [ ] **Download calendar**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
for f in CalendarPopup.qml weather.sh diary_manager.sh; do
  curl -sL "$BASE/calendar/$f" -o ~/dotfiles/quickshell/calendar/$f
done
for f in get_schedule.py schedule_manager.sh; do
  curl -sL "$BASE/calendar/schedule/$f" -o ~/dotfiles/quickshell/calendar/schedule/$f
done
```

- [ ] **Download network**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
for f in NetworkPopup.qml wifi_panel_logic.sh bluetooth_panel_logic.sh eth_panel_logic.sh; do
  curl -sL "$BASE/network/$f" -o ~/dotfiles/quickshell/network/$f 2>/dev/null || touch ~/dotfiles/quickshell/network/$f
done
```

Note: `eth_panel_logic.sh` may 404 (we write it from scratch in Task 9). That's fine — the `touch` creates an empty placeholder.

- [ ] **Download remaining popups**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"

# notifications
curl -sL "$BASE/notifications/NotificationPopups.qml" -o ~/dotfiles/quickshell/notifications/NotificationPopups.qml

# volume
for f in VolumePopup.qml audio_control.sh get_audio_state.py; do
  curl -sL "$BASE/volume/$f" -o ~/dotfiles/quickshell/volume/$f
done

# wallpaper
for f in WallpaperPicker.qml ddg_search.sh get_ddg_links.py matugen_reload.sh; do
  curl -sL "$BASE/wallpaper/$f" -o ~/dotfiles/quickshell/wallpaper/$f
done

# focustime
for f in FocusTimePopup.qml focus_daemon.py get_stats.py launch_daemon.sh; do
  curl -sL "$BASE/focustime/$f" -o ~/dotfiles/quickshell/focustime/$f
done

# clipboard
for f in ClipboardManager.qml clip_fetcher.py; do
  curl -sL "$BASE/clipboard/$f" -o ~/dotfiles/quickshell/clipboard/$f
done

# quickactions
for f in DrawAction.qml SystemUsage.qml Timer.qml; do
  curl -sL "$BASE/quickactions/$f" -o ~/dotfiles/quickshell/quickactions/$f
done

# monitors, settings, updater, guide, stewart
curl -sL "$BASE/monitors/MonitorPopup.qml" -o ~/dotfiles/quickshell/monitors/MonitorPopup.qml
curl -sL "$BASE/settings/SettingsPopup.qml" -o ~/dotfiles/quickshell/settings/SettingsPopup.qml
curl -sL "$BASE/updater/UpdaterPopup.qml" -o ~/dotfiles/quickshell/updater/UpdaterPopup.qml
curl -sL "$BASE/guide/GuidePopup.qml" -o ~/dotfiles/quickshell/guide/GuidePopup.qml
curl -sL "$BASE/stewart/stewart.qml" -o ~/dotfiles/quickshell/stewart/stewart.qml
```

- [ ] **Download watchers (no battery)**

```bash
BASE="https://raw.githubusercontent.com/ilyamiro/nixos-configuration/master/config/sessions/hyprland/scripts/quickshell"
for f in audio_fetch.sh audio_wait.sh bt_fetch.sh bt_wait.sh kb_fetch.sh kb_wait.sh network_fetch.sh network_wait.sh sys_fetcher.sh; do
  curl -sL "$BASE/watchers/$f" -o ~/dotfiles/quickshell/watchers/$f
done
# Do NOT download battery_fetch.sh or battery_wait.sh
```

- [ ] **Make all shell scripts and Python files executable**

```bash
find ~/dotfiles/quickshell -name "*.sh" -o -name "*.py" | xargs chmod +x
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/
git commit -m "feat: download quickshell source files from ilyamiro/nixos-configuration"
```

---

## Task 4: Adapt Config.qml paths

**Files:**
- Modify: `~/dotfiles/quickshell/Config.qml`

The source config expects scripts at `~/.config/hypr/scripts/quickshell`. Our scripts live at `~/.config/quickshell` (symlinked from `~/dotfiles/quickshell`).

- [ ] **Update script path in Config.qml**

```bash
sed -i 's|\.config/hypr/scripts/quickshell|.config/quickshell|g' ~/dotfiles/quickshell/Config.qml
sed -i 's|\.config/hypr/settings\.json|.config/quickshell/settings.json|g' ~/dotfiles/quickshell/Config.qml
```

- [ ] **Verify**

```bash
grep "\.config/" ~/dotfiles/quickshell/Config.qml | head -10
```

Expected: paths show `.config/quickshell`, not `.config/hypr/scripts/quickshell`.

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/Config.qml
git commit -m "fix: update Config.qml paths to ~/.config/quickshell"
```

---

## Task 5: Replace Catppuccin with Dracula in MatugenColors.qml

**Files:**
- Modify: `~/dotfiles/quickshell/MatugenColors.qml`

Replace all Catppuccin Mocha default color values with Dracula equivalents. The file defines QML properties like `property color base: "#1e1e2e"`.

- [ ] **Apply color replacements**

```bash
cd ~/dotfiles/quickshell
# Backgrounds
sed -i 's/"#1e1e2e"/"#282a36"/g' MatugenColors.qml   # base
sed -i 's/"#181825"/"#1e1f29"/g' MatugenColors.qml   # mantle
sed -i 's/"#11111b"/"#11111b"/g' MatugenColors.qml   # crust (same)

# Text
sed -i 's/"#cdd6f4"/"#f8f8f2"/g' MatugenColors.qml   # text
sed -i 's/"#a6adc8"/"#6272a4"/g' MatugenColors.qml   # subtext0
sed -i 's/"#bac2de"/"#a0a8c0"/g' MatugenColors.qml   # subtext1

# Surfaces
sed -i 's/"#313244"/"#44475a"/g' MatugenColors.qml   # surface0
sed -i 's/"#45475a"/"#44475a"/g' MatugenColors.qml   # surface1
sed -i 's/"#585b70"/"#6272a4"/g' MatugenColors.qml   # surface2

# Overlays
sed -i 's/"#6c7086"/"#6272a4"/g' MatugenColors.qml   # overlay0
sed -i 's/"#7f849c"/"#808090"/g' MatugenColors.qml   # overlay1
sed -i 's/"#9399b2"/"#9090a8"/g' MatugenColors.qml   # overlay2

# Accents
sed -i 's/"#cba6f7"/"#bd93f9"/g' MatugenColors.qml   # mauve → purple
sed -i 's/"#f5c2e7"/"#ff79c6"/g' MatugenColors.qml   # pink
sed -i 's/"#f2cdcd"/"#ff79c6"/g' MatugenColors.qml   # flamingo → pink
sed -i 's/"#f5e0dc"/"#f8f8f2"/g' MatugenColors.qml   # rosewater → text
sed -i 's/"#89b4fa"/"#8be9fd"/g' MatugenColors.qml   # blue → cyan
sed -i 's/"#74c7ec"/"#8be9fd"/g' MatugenColors.qml   # sapphire → cyan
sed -i 's/"#89dceb"/"#8be9fd"/g' MatugenColors.qml   # sky → cyan
sed -i 's/"#94e2d5"/"#50fa7b"/g' MatugenColors.qml   # teal → green
sed -i 's/"#a6e3a1"/"#50fa7b"/g' MatugenColors.qml   # green
sed -i 's/"#f9e2af"/"#f1fa8c"/g' MatugenColors.qml   # yellow
sed -i 's/"#fab387"/"#ffb86c"/g' MatugenColors.qml   # peach → orange
sed -i 's/"#eba0ac"/"#ff5555"/g' MatugenColors.qml   # maroon → red
sed -i 's/"#f38ba8"/"#ff5555"/g' MatugenColors.qml   # red
```

- [ ] **Verify no Catppuccin hex values remain**

```bash
grep -E '"#(1e1e2e|181825|313244|cdd6f4|cba6f7|f5c2e7|89b4fa|a6e3a1|f9e2af|fab387|f38ba8)"' ~/dotfiles/quickshell/MatugenColors.qml
```

Expected: no output (all replaced).

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/MatugenColors.qml
git commit -m "feat: replace Catppuccin defaults with Dracula palette in MatugenColors.qml"
```

---

## Task 6: Strip battery from TopBar.qml

**Files:**
- Modify: `~/dotfiles/quickshell/TopBar.qml`

Read the file first to understand battery component names, then remove them.

- [ ] **Find battery references**

```bash
grep -n -i "battery\|BatteryPopup\|battery_fetch\|batteryLevel\|batteryStatus" ~/dotfiles/quickshell/TopBar.qml | head -30
```

Note the line numbers of battery-related imports, property bindings, and UI components.

- [ ] **Remove battery import line**

```bash
grep -n "BatteryPopup\|battery" ~/dotfiles/quickshell/TopBar.qml | head -5
```

Remove the line that imports or references BatteryPopup. Use the exact line content found:

```bash
# Example — adjust to match actual line:
sed -i '/BatteryPopup/d' ~/dotfiles/quickshell/TopBar.qml
sed -i '/battery_fetch\|batteryLevel\|batteryStatus\|batteryPercent/d' ~/dotfiles/quickshell/TopBar.qml
```

- [ ] **Remove battery UI widget block**

The battery widget is likely a `Loader`, `Item`, or custom component in the right section of TopBar. Read the region around the battery lines:

```bash
grep -n -i "battery" ~/dotfiles/quickshell/TopBar.qml
```

For each remaining battery block (multi-line), remove it using a targeted delete. Open the file in an editor if sed ranges are needed:

```bash
# If battery block is on lines X to Y (check output above):
# sed -i 'X,Yd' ~/dotfiles/quickshell/TopBar.qml
```

- [ ] **Verify no battery references remain**

```bash
grep -i "battery" ~/dotfiles/quickshell/TopBar.qml
```

Expected: no output.

- [ ] **Remove battery popup file**

```bash
rm -f ~/dotfiles/quickshell/battery/BatteryPopup.qml
rmdir ~/dotfiles/quickshell/battery 2>/dev/null || true
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/
git commit -m "feat: strip battery widget and popup from quickshell"
```

---

## Task 7: BoringNotch center pill in TopBar.qml

**Files:**
- Modify: `~/dotfiles/quickshell/TopBar.qml`

The original TopBar has a center section with clock + weather. Replace it with the BoringNotch pill: dark pill with side gradient fade, shows HH:MM, expands on hover to show media panel.

- [ ] **Find the current center clock/weather section**

```bash
grep -n "clock\|weather\|center\|Clock\|Weather\|DateTime" ~/dotfiles/quickshell/TopBar.qml | head -20
```

- [ ] **Replace center section with BoringNotch pill**

Find the container holding the clock/weather (it will be an `Item`, `Row`, or `RowLayout` in the center). Replace its contents with:

```qml
// BoringNotch center pill
Item {
    id: notchContainer
    Layout.fillWidth: true
    height: parent.height

    Rectangle {
        id: notchPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: notchExpanded ? 480 : (mediaActive ? 340 : 260)
        height: parent.height
        color: "#11111b"
        radius: 0
        // Bottom corners rounded only
        layer.enabled: true

        // Side gradient fade (BoringNotch style)
        layer.effect: ShaderEffect {
            fragmentShader: "
                uniform sampler2D source;
                uniform float qt_Opacity;
                varying vec2 qt_TexCoord0;
                void main() {
                    vec4 c = texture2D(source, qt_TexCoord0);
                    float x = qt_TexCoord0.x;
                    float fade = smoothstep(0.0, 0.18, x) * smoothstep(1.0, 0.82, x);
                    gl_FragColor = c * fade * qt_Opacity;
                }
            "
        }

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        property bool notchExpanded: mouseArea.containsMouse
        property bool mediaActive: false  // set true when playerctl returns track info

        RowLayout {
            anchors.centerIn: parent
            spacing: 12

            // Time — always visible
            Text {
                text: Qt.formatDateTime(new Date(), "h:mm AP")
                color: "#bd93f9"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.bold: true
                letterSpacing: 1
            }

            // Media — visible when track playing
            RowLayout {
                visible: notchPill.mediaActive
                spacing: 10
                opacity: notchPill.mediaActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text { text: "·"; color: "#6272a4"; font.pixelSize: 11 }

                Rectangle {
                    width: 22; height: 22; radius: 11
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#bd93f9" }
                        GradientStop { position: 1; color: "#ff79c6" }
                    }
                }

                Text {
                    id: trackText
                    text: "Jane! — The Long Faces"  // bound to music_info.sh output
                    color: "#f8f8f2"
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                }

                Row {
                    spacing: 8
                    Repeater {
                        model: ["⏮", "⏸", "⏭"]
                        Text {
                            text: modelData
                            color: "#bd93f9"
                            font.pixelSize: 13
                            MouseArea { anchors.fill: parent; onClicked: Config.sh("player_control.sh " + (index === 0 ? "prev" : index === 1 ? "play-pause" : "next")) }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // Expanded music panel — drops from notch on hover
    Loader {
        id: musicPanelLoader
        anchors.top: notchPill.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        active: notchPill.notchExpanded
        sourceComponent: MusicPopup {}
        opacity: notchPill.notchExpanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
```

Note: Bind `trackText.text` and `notchPill.mediaActive` to the music watcher process output — check how the original TopBar.qml bound these for the clock/media section and follow the same pattern.

- [ ] **Remove seconds from any remaining clock references**

```bash
grep -n "ss\|:ss\|second" ~/dotfiles/quickshell/TopBar.qml
# Replace any format strings that include seconds:
sed -i 's/"hh:mm:ss"/"hh:mm"/g' ~/dotfiles/quickshell/TopBar.qml
sed -i "s/'hh:mm:ss'/'hh:mm'/g" ~/dotfiles/quickshell/TopBar.qml
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/TopBar.qml
git commit -m "feat: add BoringNotch center pill with time + media to TopBar"
```

---

## Task 8: Quick Settings panel — customizable tiles + theme button

**Files:**
- Modify: `~/dotfiles/quickshell/TopBar.qml`
- Modify: `~/dotfiles/quickshell/settings/SettingsPopup.qml`

Remove bluetooth chip from right side of bar. Add ⊞ Quick Settings button and 🎨 Theme button. QS panel has WiFi + BT toggles + volume slider + live-editable tile grid + settings persisted to `settings.json`.

- [ ] **Remove bluetooth chip from bar right section**

Find the bluetooth chip in TopBar.qml right section:

```bash
grep -n -i "bluetooth\|BluetoothChip\|btChip\|btStatus" ~/dotfiles/quickshell/TopBar.qml | head -10
```

Remove the bluetooth display widget from the right bar row (keep BT in QS panel only):

```bash
# Remove lines containing bluetooth chip component — adjust line numbers from above:
# sed -i 'X,Yd' ~/dotfiles/quickshell/TopBar.qml
```

- [ ] **Add QS and Theme buttons to bar right section**

After the volume chip in the right RowLayout, add:

```qml
// Theme picker button
Rectangle {
    width: 32; height: 26; radius: 8; color: "#44475a"
    Text { anchors.centerIn: parent; text: "🎨"; font.pixelSize: 13 }
    MouseArea { anchors.fill: parent; onClicked: themePanel.visible = !themePanel.visible }
}

// Quick Settings button
Rectangle {
    width: 110; height: 26; radius: 8
    color: qsPanel.visible ? "#bd93f920" : "#44475a"
    border.color: qsPanel.visible ? "#bd93f9" : "transparent"
    border.width: 1
    Row {
        anchors.centerIn: parent; spacing: 6
        Text { text: "⊞"; color: qsPanel.visible ? "#bd93f9" : "#f8f8f2"; font.pixelSize: 13 }
        Text { text: "Quick Settings"; color: qsPanel.visible ? "#bd93f9" : "#f8f8f2"; font.pixelSize: 11; font.family: "JetBrains Mono" }
    }
    MouseArea { anchors.fill: parent; onClicked: qsPanel.visible = !qsPanel.visible }
}
```

- [ ] **Add QS panel Loader to Floating.qml**

Open `~/dotfiles/quickshell/Floating.qml` and add the QS panel as a floating window anchored top-right:

```qml
// Quick Settings panel
Loader {
    id: qsPanel
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 46
    anchors.rightMargin: 8
    visible: false
    active: visible
    sourceComponent: QuickSettingsPanel {}
}

// Theme picker panel
Loader {
    id: themePanel
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 46
    anchors.rightMargin: 8
    visible: false
    active: visible
    sourceComponent: ThemePickerPanel {}
}
```

- [ ] **Create QuickSettingsPanel.qml**

Create `~/dotfiles/quickshell/QuickSettingsPanel.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    width: 340
    color: "#1e1f29"
    radius: 16
    border.color: "#44475a40"
    border.width: 1

    // Tile list persisted via Config.getSetting("qsTiles") — default ["wifi","bt"]
    property var activeTiles: JSON.parse(Config.getSetting("qsTiles") || '["wifi","bt"]')

    function saveTiles() {
        Config.setSetting("qsTiles", JSON.stringify(activeTiles))
    }

    property bool editMode: false

    implicitHeight: content.implicitHeight + 28

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 8

        // Header
        RowLayout {
            Text { text: "Quick Settings"; color: "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono"; Layout.fillWidth: true }
            Rectangle {
                width: editLabel.implicitWidth + 20; height: 22; radius: 6
                color: root.editMode ? "#bd93f915" : "transparent"
                border.color: root.editMode ? "#bd93f9" : "#44475a"; border.width: 1
                Text { id: editLabel; anchors.centerIn: parent; text: root.editMode ? "Done" : "Edit"; color: root.editMode ? "#bd93f9" : "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono" }
                MouseArea { anchors.fill: parent; onClicked: root.editMode = !root.editMode }
            }
        }

        // Tile grid — rendered dynamically from activeTiles
        // (Implementation: Repeater over activeTiles array, each tile is a QSTile component)
        // See QSTile.qml for tile component

        // Volume slider
        RowLayout {
            spacing: 8
            Text { text: "🔊"; font.pixelSize: 13 }
            Slider {
                id: volSlider
                Layout.fillWidth: true
                from: 0; to: 100
                value: parseInt(Config.sh("pamixer --get-volume").trim()) || 45
                onMoved: Config.sh("pamixer --set-volume " + Math.round(value))
            }
        }
    }
}
```

- [ ] **Create ThemePickerPanel.qml**

Create `~/dotfiles/quickshell/ThemePickerPanel.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    width: 300
    color: "#1e1f29"
    radius: 16
    border.color: "#44475a40"
    border.width: 1
    implicitHeight: col.implicitHeight + 28

    property var themes: [
        { id: "dracula",  name: "Dracula",  desc: "Deep purple & pink",        dots: ["#bd93f9","#ff79c6","#8be9fd"], bg: "#282a36"   },
        { id: "wisp",     name: "Wisp",     desc: "Dreamy mauve & lavender",   dots: ["#5f3e65","#c8adbe","#ddbdd1"], bg: "#3a2545"   },
        { id: "shoegaze", name: "Shoegaze", desc: "Black, white & grain",       dots: ["#111","#888","#f0f0f0"],       bg: "#111111"   },
        { id: "fawning",  name: "Fawning",  desc: "Night sky & ice blue",       dots: ["#060810","#1e3a5a","#c8ddf0"], bg: "#060810"  },
        { id: "auto",     name: "Auto",     desc: "Generated from wallpaper",   dots: ["#44475a","#6272a4","#bd93f9"], bg: "#1e1e2e"  }
    ]

    property string activeTheme: Config.getSetting("theme") || "dracula"

    function applyTheme(themeId) {
        activeTheme = themeId
        Config.setSetting("theme", themeId)
        if (themeId === "dracula") writeThemeColors(draculaColors)
        else if (themeId === "wisp") writeThemeColors(wispColors)
        else if (themeId === "shoegaze") writeThemeColors(shoegazeColors)
        else if (themeId === "fawning") writeThemeColors(fawningColors)
        else if (themeId === "auto") Config.sh("~/.config/quickshell/wallpaper/matugen_reload.sh")
    }

    property var draculaColors: ({
        base: "#282a36", mantle: "#1e1f29", crust: "#11111b",
        text: "#f8f8f2", subtext0: "#6272a4",
        surface0: "#44475a", surface1: "#44475a",
        mauve: "#bd93f9", pink: "#ff79c6", blue: "#8be9fd",
        green: "#50fa7b", yellow: "#f1fa8c", peach: "#ffb86c",
        red: "#ff5555"
    })
    property var wispColors: ({
        base: "#2a1f33", mantle: "#221829", crust: "#180e20",
        text: "#f3d9d9", subtext0: "#a793b3",
        surface0: "#3d2850", surface1: "#4a3060",
        mauve: "#c8adbe", pink: "#ddbdd1", blue: "#a793b3",
        green: "#c8adbe", yellow: "#ddbdd1", peach: "#f3d9d9",
        red: "#b07090"
    })
    property var shoegazeColors: ({
        base: "#0a0a0a", mantle: "#080808", crust: "#050505",
        text: "#f0f0f0", subtext0: "#888888",
        surface0: "#1a1a1a", surface1: "#222222",
        mauve: "#d0d0d0", pink: "#e0e0e0", blue: "#c0c0c0",
        green: "#b0b0b0", yellow: "#e8e8e8", peach: "#c8c8c8",
        red: "#a0a0a0"
    })
    property var fawningColors: ({
        base: "#060810", mantle: "#080c14", crust: "#040608",
        text: "#dde8f0", subtext0: "#6a8aaa",
        surface0: "#0d1520", surface1: "#121e2e",
        mauve: "#c8ddf0", pink: "#a8c4d8", blue: "#8ab4d0",
        green: "#7ab0c8", yellow: "#d0e4f0", peach: "#b0cce0",
        red: "#6888a8"
    })

    function writeThemeColors(colors) {
        var json = JSON.stringify(colors)
        Config.sh("echo '" + json + "' > /tmp/qs_colors.json")
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 8

        Text { text: "Theme"; color: "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono" }

        Repeater {
            model: root.themes
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 52; radius: 12
                color: modelData.bg
                border.color: root.activeTheme === modelData.id ? "#f8f8f2" : "transparent"
                border.width: 2

                RowLayout {
                    anchors { fill: parent; margins: 12 }
                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData.dots
                            Rectangle { width: 12; height: 12; radius: 6; color: modelData }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: modelData.name; color: "#f8f8f2"; font.pixelSize: 12; font.bold: true; font.family: "JetBrains Mono" }
                        Text { text: modelData.desc; color: "rgba(255,255,255,0.4)"; font.pixelSize: 10; font.family: "JetBrains Mono" }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: root.applyTheme(modelData.id) }
            }
        }
    }
}
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/
git commit -m "feat: add quick settings panel and theme picker to quickshell"
```

---

## Task 9: Ethernet expandable tile + eth_panel_logic.sh

**Files:**
- Create: `~/dotfiles/quickshell/network/eth_panel_logic.sh`
- Create: `~/dotfiles/quickshell/EthernetTile.qml`

- [ ] **Write eth_panel_logic.sh**

Create `~/dotfiles/quickshell/network/eth_panel_logic.sh`:

```bash
#!/usr/bin/env bash
# Usage: eth_panel_logic.sh <command> [args]
# Commands: list-connections, get-active, apply-static, apply-dhcp

CMD="$1"

case "$CMD" in
  list-connections)
    # Output: name|ip|prefix|gateway|is_active (one per line)
    active_uuid=$(nmcli -t -f UUID,DEVICE con show --active 2>/dev/null | grep "eno1\|eth" | cut -d: -f1)
    nmcli -t -f NAME,UUID,TYPE con show | grep ethernet | while IFS=: read name uuid type; do
      is_active="false"
      [[ "$uuid" == "$active_uuid" ]] && is_active="true"
      ip=$(nmcli -t -f ipv4.addresses con show "$uuid" | cut -d: -f2 | tr -d ' ')
      gw=$(nmcli -t -f ipv4.gateway con show "$uuid" | cut -d: -f2 | tr -d ' ')
      echo "${name}|${ip}|${gw}|${is_active}"
    done
    ;;

  apply-static)
    # args: <connection-name> <ip/prefix> <gateway> <dns1> <dns2>
    NAME="$2" IP="$3" GW="$4" DNS1="$5" DNS2="$6"
    nmcli con mod "$NAME" ipv4.method manual ipv4.addresses "$IP" ipv4.gateway "$GW" ipv4.dns "$DNS1 $DNS2"
    nmcli con up "$NAME"
    echo "applied"
    ;;

  apply-dhcp)
    # args: <connection-name>
    NAME="$2"
    nmcli con mod "$NAME" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
    nmcli con up "$NAME"
    echo "applied"
    ;;
esac
```

```bash
chmod +x ~/dotfiles/quickshell/network/eth_panel_logic.sh
```

- [ ] **Create EthernetTile.qml**

Create `~/dotfiles/quickshell/EthernetTile.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: header.height + (expanded ? body.implicitHeight : 0)
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property bool expanded: false
    property string openEditor: ""
    property var connections: []

    Component.onCompleted: loadConnections()

    function loadConnections() {
        var proc = Config.sh("~/.config/quickshell/network/eth_panel_logic.sh list-connections")
        var lines = proc.trim().split("\n").filter(l => l.length > 0)
        connections = lines.map(l => {
            var p = l.split("|")
            return { name: p[0], ip: p[1], gateway: p[2], active: p[3] === "true" }
        })
    }

    // Header
    Rectangle {
        id: header
        width: parent.width; height: 44
        color: "#282a36"; radius: expanded ? 0 : 12

        RowLayout {
            anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
            Text { text: "🔌"; font.pixelSize: 17 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                RowLayout {
                    Text { text: "Ethernet"; color: "#f8f8f2"; font.pixelSize: 11; font.bold: true; font.family: "JetBrains Mono" }
                    Rectangle { width: 8; height: 8; radius: 4; color: "#50fa7b"; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    text: root.connections.length > 0 ? root.connections.find(c => c.active)?.ip || "no IP" : "loading..."
                    color: "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono"
                }
            }
            Text {
                text: "▼"; color: "#6272a4"; font.pixelSize: 10
                rotation: root.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 250 } }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: { root.expanded = !root.expanded; if (root.expanded) root.loadConnections() } }
    }

    // Body
    Rectangle {
        id: body
        anchors.top: header.bottom; width: parent.width
        color: "#11111b"
        implicitHeight: bodyCol.implicitHeight + 16
        visible: root.expanded

        ColumnLayout {
            id: bodyCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 6

            Repeater {
                model: root.connections
                delegate: Rectangle {
                    Layout.fillWidth: true
                    color: modelData.active ? "#8be9fd08" : "#282a36"; radius: 10
                    border.color: modelData.active ? "#8be9fd50" : "transparent"; border.width: 1
                    implicitHeight: connCol.implicitHeight + 20

                    ColumnLayout {
                        id: connCol
                        anchors { left: parent.left; right: parent.right; margins: 12 }
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        RowLayout {
                            Text { text: modelData.name; color: modelData.active ? "#8be9fd" : "#f8f8f2"; font.pixelSize: 11; font.bold: true; font.family: "JetBrains Mono"; Layout.fillWidth: true }
                            Rectangle {
                                width: badgeText.implicitWidth + 12; height: 16; radius: 4
                                color: modelData.active ? "#50fa7b20" : "#44475a"
                                Text { id: badgeText; anchors.centerIn: parent; text: modelData.active ? "active" : "saved"; color: modelData.active ? "#50fa7b" : "#6272a4"; font.pixelSize: 9; font.family: "JetBrains Mono" }
                            }
                        }
                        Text { text: (modelData.ip || "no IP") + " · GW " + (modelData.gateway || "—"); color: "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono" }

                        // IP Editor
                        Loader {
                            id: editorLoader
                            Layout.fillWidth: true
                            active: root.openEditor === modelData.name
                            sourceComponent: IPEditor { connectionName: modelData.name; currentIp: modelData.ip; currentGw: modelData.gateway }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openEditor = (root.openEditor === modelData.name ? "" : modelData.name)
                    }
                }
            }

            // Add connection placeholder
            Rectangle {
                Layout.fillWidth: true; height: 36; radius: 8; color: "transparent"
                border.color: "#44475a"; border.width: 1; border.style: Qt.DashLine
                Text { anchors.centerIn: parent; text: "+ Add connection"; color: "#6272a4"; font.pixelSize: 10; font.family: "JetBrains Mono" }
            }
        }
    }
}
```

- [ ] **Create IPEditor.qml**

Create `~/dotfiles/quickshell/IPEditor.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    color: "#1a1b26"; radius: 8; border.color: "#44475a30"; border.width: 1
    implicitHeight: formCol.implicitHeight + 20

    required property string connectionName
    required property string currentIp
    required property string currentGw

    property bool dhcp: false

    ColumnLayout {
        id: formCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 6

        // DHCP toggle
        RowLayout {
            Text { text: "DHCP (automatic)"; color: "#f8f8f2"; font.pixelSize: 11; font.family: "JetBrains Mono"; Layout.fillWidth: true }
            Rectangle {
                id: dhcpSwitch
                width: 34; height: 18; radius: 9
                color: root.dhcp ? "#8be9fd" : "#44475a"
                Rectangle {
                    id: knob; width: 14; height: 14; radius: 7; color: "#f8f8f2"
                    x: root.dhcp ? 17 : 2; anchors.verticalCenter: parent.verticalCenter
                    Behavior on x { NumberAnimation { duration: 200 } }
                }
                MouseArea { anchors.fill: parent; onClicked: { root.dhcp = !root.dhcp } }
            }
        }

        Text { text: "IP ADDRESS"; color: "#6272a4"; font.pixelSize: 9; font.family: "JetBrains Mono"; letterSpacing: 0.8 }
        TextField {
            id: ipField
            Layout.fillWidth: true
            text: root.currentIp?.split("/")[0] || ""
            enabled: !root.dhcp
            font.family: "JetBrains Mono"; font.pixelSize: 11
            color: "#f8f8f2"; background: Rectangle { color: "#282a36"; radius: 7; border.color: ipField.activeFocus ? "#8be9fd80" : "#44475a"; border.width: 1 }
            opacity: root.dhcp ? 0.4 : 1
        }

        RowLayout {
            spacing: 6
            ColumnLayout {
                Text { text: "PREFIX"; color: "#6272a4"; font.pixelSize: 9; font.family: "JetBrains Mono" }
                TextField {
                    width: 60
                    text: root.currentIp?.split("/")[1] || "24"
                    enabled: !root.dhcp; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: "#44475a"; border.width: 1 }
                    opacity: root.dhcp ? 0.4 : 1
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: "GATEWAY"; color: "#6272a4"; font.pixelSize: 9; font.family: "JetBrains Mono" }
                TextField {
                    id: gwField
                    Layout.fillWidth: true
                    text: root.currentGw || ""
                    enabled: !root.dhcp; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                    background: Rectangle { color: "#282a36"; radius: 7; border.color: gwField.activeFocus ? "#8be9fd80" : "#44475a"; border.width: 1 }
                    opacity: root.dhcp ? 0.4 : 1
                }
            }
        }

        RowLayout {
            spacing: 6
            Repeater {
                model: [{label: "DNS PRIMARY", val: "1.1.1.1"}, {label: "DNS SECONDARY", val: "8.8.8.8"}]
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: modelData.label; color: "#6272a4"; font.pixelSize: 9; font.family: "JetBrains Mono" }
                    TextField {
                        id: dnsField
                        objectName: "dns" + index
                        Layout.fillWidth: true; text: modelData.val
                        enabled: !root.dhcp; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#f8f8f2"
                        background: Rectangle { color: "#282a36"; radius: 7; border.color: "#44475a"; border.width: 1 }
                        opacity: root.dhcp ? 0.4 : 1
                    }
                }
            }
        }

        // Apply button
        Rectangle {
            Layout.fillWidth: true; height: 32; radius: 7
            color: "#8be9fd15"; border.color: "#8be9fd50"; border.width: 1
            Text { anchors.centerIn: parent; text: "Apply via nmcli"; color: "#8be9fd"; font.pixelSize: 10; font.family: "JetBrains Mono" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.dhcp) {
                        Config.sh("~/.config/quickshell/network/eth_panel_logic.sh apply-dhcp '" + root.connectionName + "'")
                    } else {
                        var ip = ipField.text + "/24"
                        var dns = formCol.children  // collect dns fields
                        Config.sh("~/.config/quickshell/network/eth_panel_logic.sh apply-static '" + root.connectionName + "' '" + ip + "' '" + gwField.text + "' '1.1.1.1' '8.8.8.8'")
                    }
                }
            }
        }
    }
}
```

- [ ] **Add EthernetTile to QuickSettingsPanel**

In `~/dotfiles/quickshell/QuickSettingsPanel.qml`, add inside the ColumnLayout after the tile grid:

```qml
EthernetTile {
    Layout.fillWidth: true
}
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add quickshell/
git commit -m "feat: add expandable ethernet tile with NetworkManager IP editor"
```

---

## Task 10: Alacritty configuration

**Files:**
- Create: `~/dotfiles/alacritty/alacritty.toml`
- Create: `~/.config/alacritty/alacritty.toml` (symlink)

- [ ] **Create alacritty directory and symlink**

```bash
mkdir -p ~/dotfiles/alacritty
mkdir -p ~/.config/alacritty
ln -sf ~/dotfiles/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
```

- [ ] **Write alacritty.toml**

Create `~/dotfiles/alacritty/alacritty.toml`:

```toml
[window]
opacity = 0.88
blur = true
padding = { x = 16, y = 12 }
decorations = "None"
startup_mode = "Windowed"

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size = 11.0

[colors.primary]
background = "#282a36"
foreground = "#f8f8f2"

[colors.cursor]
text = "#282a36"
cursor = "#bd93f9"

[colors.selection]
text = "#f8f8f2"
background = "#44475a"

[colors.normal]
black   = "#21222c"
red     = "#ff5555"
green   = "#50fa7b"
yellow  = "#f1fa8c"
blue    = "#bd93f9"
magenta = "#ff79c6"
cyan    = "#8be9fd"
white   = "#f8f8f2"

[colors.bright]
black   = "#6272a4"
red     = "#ff6e6e"
green   = "#69ff94"
yellow  = "#ffffa5"
blue    = "#d6acff"
magenta = "#ff92df"
cyan    = "#a4ffff"
white   = "#ffffff"

[cursor]
style = { shape = "Block", blinking = "On" }
blink_interval = 500

[scrolling]
history = 10000

[env]
TERM = "xterm-256color"
```

- [ ] **Install JetBrains Mono Nerd Font if not present**

```bash
fc-list | grep -i "JetBrainsMono" | head -3
```

If empty, add `nerd-fonts` or `nerdfonts` to `configuration.nix` and rebuild. If `JetBrains Mono` (non-Nerd) is present, change font family in `alacritty.toml` to `"JetBrains Mono"`.

- [ ] **Test Alacritty launches**

```bash
alacritty &
```

Expected: transparent terminal window opens with Dracula colors. Close it.

- [ ] **Commit**

```bash
cd ~/dotfiles
git add alacritty/
git commit -m "feat: add Alacritty config with Dracula theme and transparency"
```

---

## Task 11: Zsh prompt (Dracula, daniel@nixosbtw style)

**Files:**
- Modify: `~/.zshrc` or `~/dotfiles/zsh/.zshrc` (check which is used)

- [ ] **Find zsh config location**

```bash
ls ~/dotfiles/zsh/ 2>/dev/null || echo "no dotfiles/zsh"; ls ~/.zshrc 2>/dev/null
```

- [ ] **Set Dracula prompt**

Add to the end of your zsh config file:

```zsh
# Dracula prompt — daniel@nixosbtw [~] > >
autoload -Uz colors && colors

PROMPT='%F{#ff79c6}%n@%m%f %F{#bd93f9}[%~]%f
%F{#bd93f9}>%f %F{#6272a4}>%f '

# No right prompt
RPROMPT=''
```

This matches image 4: pink `daniel@nixosbtw`, purple `[~]`, then `> >` arrows on a new line.

- [ ] **Reload and verify**

```bash
source ~/.zshrc
```

Expected: prompt shows `daniel@nixosbtw [~]` in pink/purple, then `> >` in purple/grey.

- [ ] **Commit**

```bash
cd ~/dotfiles
git add .
git commit -m "feat: add Dracula zsh prompt matching reference style"
```

---

## Task 12: fastfetch configuration

**Files:**
- Create: `~/dotfiles/fastfetch/config.jsonc`
- Create: `~/.config/fastfetch/config.jsonc` (symlink)

- [ ] **Create fastfetch directory and symlink**

```bash
mkdir -p ~/dotfiles/fastfetch
mkdir -p ~/.config/fastfetch
ln -sf ~/dotfiles/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
```

- [ ] **Write fastfetch config**

Create `~/dotfiles/fastfetch/config.jsonc`:

```jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "nixos",
    "color": {
      "1": "cyan",
      "2": "blue"
    },
    "padding": { "top": 1, "left": 2 }
  },
  "display": {
    "separator": " • ",
    "color": {
      "keys": "cyan",
      "title": "magenta",
      "separator": "blue"
    }
  },
  "modules": [
    {
      "type": "title",
      "format": "{user-name}@{host-name}"
    },
    "break",
    {
      "type": "os",
      "key": "distribution",
      "keyColor": "cyan"
    },
    {
      "type": "kernel",
      "key": "linux kernel",
      "keyColor": "cyan"
    },
    {
      "type": "packages",
      "key": "packages",
      "keyColor": "cyan"
    },
    {
      "type": "shell",
      "key": "unix shell",
      "keyColor": "cyan"
    },
    {
      "type": "terminal",
      "key": "terminal",
      "keyColor": "cyan"
    },
    {
      "type": "wm",
      "key": "window manager",
      "keyColor": "cyan"
    },
    "break",
    {
      "type": "colors",
      "paddingLeft": 0,
      "symbol": "circle"
    }
  ]
}
```

- [ ] **Test fastfetch**

```bash
fastfetch
```

Expected: NixOS logo in cyan on left, `daniel@nixosbtw` title, system info rows with cyan keys, color circles at bottom. Layout matches the reference screenshot style.

- [ ] **Commit**

```bash
cd ~/dotfiles
git add fastfetch/
git commit -m "feat: add fastfetch config with NixOS logo and Dracula colors"
```

---

## Task 13: Autostart — remove waybar/eww, add quickshell

**Files:**
- Modify: `~/dotfiles/hypr/configs/autostart.conf`

- [ ] **Update autostart.conf**

Current content includes:
```
exec-once = waybar
exec-once = eww daemon
# exec-once = sleep 1 && eww open media_island
```

Remove those lines and add quickshell:

```bash
sed -i '/exec-once = waybar/d' ~/dotfiles/hypr/configs/autostart.conf
sed -i '/exec-once = eww/d' ~/dotfiles/hypr/configs/autostart.conf
sed -i '/eww open/d' ~/dotfiles/hypr/configs/autostart.conf
echo "exec-once = quickshell" >> ~/dotfiles/hypr/configs/autostart.conf
```

- [ ] **Verify autostart.conf**

```bash
cat ~/dotfiles/hypr/configs/autostart.conf
```

Expected: no waybar or eww lines, `exec-once = quickshell` present.

- [ ] **Commit**

```bash
cd ~/dotfiles
git add hypr/configs/autostart.conf
git commit -m "feat: remove waybar and eww autostart, add quickshell"
```

---

## Task 14: Remove waybar directory

**Files:**
- Delete: `~/dotfiles/waybar/`

- [ ] **Remove waybar directory**

```bash
rm -rf ~/dotfiles/waybar/
```

- [ ] **Commit**

```bash
cd ~/dotfiles
git add -A
git commit -m "chore: remove waybar config directory (replaced by quickshell)"
```

---

## Task 15: Kill running waybar/eww and launch quickshell

- [ ] **Stop waybar and eww**

```bash
pkill waybar 2>/dev/null; pkill eww 2>/dev/null; eww kill 2>/dev/null; true
```

- [ ] **Launch quickshell**

```bash
quickshell &
```

Expected: quickshell starts, top bar appears across both monitors.

- [ ] **Verify bar is visible**

Check that the bar renders on both monitors. If it crashes, check:

```bash
journalctl --user -u quickshell -n 50
# or run directly and read stderr:
quickshell 2>&1 | head -50
```

Common issues:
- Missing QML import: install the relevant Qt package in `configuration.nix`
- Script path wrong: re-check Task 4 path substitution
- Python script fails: run it manually, e.g. `python3 ~/.config/quickshell/applauncher/app_fetcher.py`

- [ ] **Commit final state**

```bash
cd ~/dotfiles
git add -A
git commit -m "feat: quickshell pookie — full shell replacement complete"
```

---

## Task 16: Push backup to GitHub

- [ ] **Run backup script**

```bash
bash ~/dotfiles/hypr/scripts/backup.sh
```

Expected: force-pushes to GitHub. Verify at your repo URL.

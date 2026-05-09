# Quickshell Pookie — Design Spec

**Date:** 2026-05-09  
**Status:** Approved  
**Scope:** Full Wayland desktop shell replacement using Quickshell (QML/Qt), ported from ilyamiro/nixos-configuration, Dracula-themed, adapted for desktop (no battery), dual 1440p monitors.

---

## 1. Overview

Replace waybar + eww entirely with a single Quickshell configuration. Source: `ilyamiro/nixos-configuration` — all QML + shell scripts ported to `~/dotfiles/quickshell/`, symlinked to `~/.config/hypr/scripts/quickshell/`. Autostart via `exec-once = quickshell` in `~/dotfiles/hypr/configs/autostart.conf`.

---

## 2. Top Bar

Single bar spanning the full width of each monitor. Three zones:

**Left:** Search launcher (🔍) → expands to spotlight-style app/file search overlay (`appLauncher.qml` + `app_fetcher.py`). Notification bell (🔔) → expands notification centre panel. Workspace indicators (1–8), active workspace highlighted in accent color.

**Center:** BoringNotch pill — dark (`#11111b`), rounded bottom corners, gradient fade on both sides via CSS mask. Always shows `HH:MM AM/PM` (no seconds). When media plays: album art thumbnail + track name + inline prev/play/next controls appear alongside the time. Hover → full music panel drops from center of bar (album art, progress scrubber, EQ sliders + 8 presets). Hover-lost → collapses. Weather is **not** shown in the bar — lives only in the calendar popup.

**Right:** WiFi chip (shows SSID), Volume chip (shows %), 🎨 Theme button, ⊞ Quick Settings button. No battery widget. No bluetooth chip (bluetooth lives in Quick Settings).

---

## 3. BoringNotch — Media Integration

Uses `playerctl` with explicit player priority:

```
playerctl --player=spotify,firefox,chromium,jellyfin,%any
```

All players expose MPRIS via D-Bus. Album art fetched from `mpris:artUrl` (handles both `https://` remote URLs and local file URLs — cached locally to prevent flicker). EQ uses EasyEffects preset loading via `easyeffects --load-preset NAME`. Presets: Flat, Bass, Treble, Vocal, Pop, Rock, Jazz, Classic.

---

## 4. Quick Settings Panel

Drops from top-right button. Fully customizable — Edit mode lets user add/remove widget tiles live. State persisted to `~/.config/hypr/settings.json` via `Config.qml`.

**Default tiles:** WiFi toggle (SSID), Bluetooth toggle (connected device).

**Expandable Ethernet tile:** Click to expand → shows NetworkManager connections list. Click any connection → inline IP editor: DHCP toggle, IP, subnet/prefix, gateway, DNS primary/secondary. Apply writes config via `nmcli`. Active connection marked with green badge.

**Volume slider.** 

**Available widgets to add:** GPU usage, CPU, RAM, Net speed, Mic mute, Idle lock, Clipboard, Focus time, Weather, System updates.

---

## 5. Notification Centre

Expands from the bell icon. Stacked notification cards grouped by app. Dismiss individual or clear all. Uses Quickshell's built-in notification IPC (`NotificationPopups.qml`).

---

## 6. Theme System

### Theme Picker (separate panel, 🎨 button)
Five themes, stored as color presets written to `/tmp/qs_colors.json`. `MatugenColors.qml` hot-reloads this file every second.

| Theme | Palette | Vibe |
|---|---|---|
| **Dracula** | `#282a36` bg, `#bd93f9` purple, `#ff79c6` pink, `#8be9fd` cyan | Default |
| **Wisp** | `#5f3e65` deep purple → `#c8adbe` lavender → `#ddbdd1` blush | Dreamy shoegaze |
| **Shoegaze** | `#0a0a0a` bg, `#888` mid, `#f0f0f0` text, film grain | Washed-out black/white |
| **Fawning** | `#060810` bg, `#0d1520` surface, `#c8ddf0` ice blue, silver sparkle | Night sky / Vixsin |
| **Auto** | matugen-generated from wallpaper | Dynamic |

**Dracula is the default** — written to `MatugenColors.qml` as static defaults so first boot looks correct before any wallpaper is picked.

### Auto theming
When wallpaper is changed via the wallpaper picker, `matugen_reload.sh` runs `matugen` against the new wallpaper, writes `/tmp/qs_colors.json`, and `MatugenColors.qml` picks it up within 1 second. Selecting a named theme writes that theme's palette to the same file, overriding matugen output until "Auto" is re-selected.

---

## 7. Popups

All ported from source repo, battery popup excluded:

- **Calendar + Weather** — full-screen overlay: clock (HH:MM), weather forecast arc, calendar, schedule. Weather via OpenWeatherMap API (key stored in `.env` in calendar dir).
- **Music popup** — standalone floating panel (also accessible outside the notch hover).
- **Network popup** — WiFi + Bluetooth panels. Bluetooth uses radial graph layout.
- **Volume popup** — audio device selector + slider.
- **Wallpaper picker** — diagonal photo strip, DDG image search, sets wallpaper + triggers matugen if Auto theme active.
- **Focus time tracker** — daily app usage stats via Python daemon (`focus_daemon.py`).
- **Clipboard manager** — recent clips via `wl-clipboard` + `clip_fetcher.py`.
- **Screenshot overlay** — region/window/full capture.
- **Lock screen** — `hyprlock`.
- **Quick actions** — timer, system usage, draw overlay.
- **Settings popup** — keybinds, startup entries, display config.

---

## 8. Removed Components

- `battery/BatteryPopup.qml` — deleted
- `watchers/battery_fetch.sh`, `watchers/battery_wait.sh` — deleted
- Battery widget from `TopBar.qml`
- `exec-once = waybar` from autostart
- `exec-once = eww daemon && eww open dynamic_island` from autostart
- Waybar autostart (configs kept in dotfiles but not started)

---

## 9. Alacritty Terminal

**Package:** `alacritty` added to `configuration.nix`.

**Config:** `~/dotfiles/alacritty/alacritty.toml`  
**Symlink:** `~/.config/alacritty/alacritty.toml`  
**Package:** added to `~/dotfiles/nixos/configuration.nix`

- Background opacity: `0.85`, blur enabled
- Font: JetBrains Mono 11pt (from `~/dotfiles/quickshell/fonts/`)
- Colors: Dracula palette (pink `#ff79c6` for user@host, purple `#bd93f9` for path/brackets, cyan `#8be9fd` for prompt arrows)
- Prompt style (zsh): `daniel@nixosbtw [~]` + `> >` arrows — matches image reference
- fastfetch config: NixOS ASCII art left, system info right, colored to match active theme

---

## 10. Thunar File Manager

**Package:** `thunar` added to `configuration.nix`.  
GTK theme configured to match active Quickshell theme via GTK CSS overrides.

---

## 11. NixOS Packages

Add to `configuration.nix` (environment.systemPackages or home-manager):

```nix
quickshell        # already installed
alacritty         # GPU terminal
thunar            # file manager
matugen           # wallpaper → color generation
playerctl         # MPRIS media control
easyeffects       # EQ
wl-clipboard      # clipboard (wl-copy/wl-paste)
jq                # JSON parsing in shell scripts
curl              # weather API
hyprlock          # lock screen
python3           # focus daemon, app fetcher, clipboard fetcher
networkmanager    # likely present; confirm nmcli available
bluez             # bluetooth
bluez-utils       # bluetoothctl
```

---

## 12. File Layout

```
~/dotfiles/quickshell/
├── Main.qml / Shell.qml / Config.qml / Caching.qml
├── TopBar.qml                    # battery stripped, notch added
├── MatugenColors.qml             # Catppuccin defaults → Dracula
├── Floating.qml / Lock.qml / ScreenshotOverlay.qml
├── SysData.qml / Scaler.qml / WindowRegistry.js
├── fonts/                        # JetBrains Mono (reused by Alacritty)
├── applauncher/                  # appLauncher.qml + app_fetcher.py
├── music/                        # MusicPopup.qml + scripts
├── calendar/                     # CalendarPopup.qml + weather.sh
├── network/                      # NetworkPopup.qml + bt/wifi/eth scripts
├── notifications/                # NotificationPopups.qml
├── volume/                       # VolumePopup.qml + audio scripts
├── wallpaper/                    # WallpaperPicker.qml + DDG search
├── focustime/                    # FocusTimePopup.qml + daemon
├── clipboard/                    # ClipboardManager.qml + fetcher
├── quickactions/                 # Timer, SystemUsage, DrawAction
├── monitors/                     # MonitorPopup.qml
├── settings/                     # SettingsPopup.qml
├── updater/                      # UpdaterPopup.qml
└── watchers/                     # network/bt/kb/sys fetchers (battery removed)

~/dotfiles/alacritty/
└── alacritty.toml

~/dotfiles/hypr/configs/autostart.conf
  exec-once = quickshell          # replaces waybar + eww lines
```

---

## 13. Cleanup

- Remove `~/dotfiles/waybar/` directory entirely (waybar replaced, configs no longer needed)
- Remove waybar and eww autostart lines from `~/dotfiles/hypr/configs/autostart.conf`

---

## 14. Out of Scope

- Alacritty replacing vs. alongside kitty — both will be installed; user decides default separately.
- EasyEffects presets — user creates these in the GUI; we wire the preset names only.
- OpenWeatherMap API key — user must obtain and set in `.env`.
- Schedule/diary data — file format documented, starts empty.

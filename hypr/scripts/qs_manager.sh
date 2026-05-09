#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

qs_ensure_cache "workspaces"
qs_ensure_cache "network"
qs_ensure_cache "wallpaper_picker"

BT_PID_FILE="$QS_RUN_DIR/bt_scan_pid"
BT_SCAN_LOG="$QS_LOG_DIR/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$QS_CACHE_WALLPAPER_PICKER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"

export MAGICK_THREAD_LIMIT=1

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
mkdir -p "$QS_NETWORK_CACHE" "${THUMB_DIR:-/tmp/qs_thumbs}"

IPC_FILE="$QS_RUN_DIR/widget_state"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    echo "close" > "$IPC_FILE"
    CMD="workspace $ACTION"
    [[ "$2" == "move" ]] && CMD="movetoworkspace $ACTION"
    hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    exit 0
fi

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) >/dev/null 2>&1 &
}

# Zombie watchdog — restart quickshell if it died
QS_SHELL_QML="$HOME/.config/quickshell/Shell.qml"
if ! pgrep -f "quickshell" >/dev/null; then
    quickshell -p "$QS_SHELL_QML" >/dev/null 2>&1 &
    disown
fi

if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
        [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
        echo "$ACTION:$TARGET:$SUBTARGET" > "$IPC_FILE"
        exit 0
    fi
    echo "$ACTION:$TARGET:$SUBTARGET" > "$IPC_FILE"
    exit 0
fi

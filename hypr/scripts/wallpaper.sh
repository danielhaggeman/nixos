#!/usr/bin/env bash
# Usage: wallpaper.sh /path/to/image  OR  wallpaper.sh (random from ~/wallpapers/)
WALLPAPER_DIR="$HOME/wallpapers"

if [[ -n "$1" ]]; then
    WP="$1"
else
    WP=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null | shuf -n1)
fi
[[ -z "$WP" ]] && echo "No wallpaper found" && exit 1

# 1. Set wallpaper
swww img "$WP" --transition-type grow --transition-pos center --transition-duration 1.2 --transition-fps 60

# 2. Generate wal colors
wal -i "$WP" -n -q 2>/dev/null

# 3. Reload waybar
pkill waybar; sleep 0.3; WAYLAND_DISPLAY=wayland-1 waybar &>/dev/null &

# 4. Reload kitty colors
pkill -USR1 kitty 2>/dev/null

# 5. Reload eww
eww kill 2>/dev/null; sleep 0.3; eww daemon; sleep 0.3; eww open media_island

echo "Wallpaper: $WP"

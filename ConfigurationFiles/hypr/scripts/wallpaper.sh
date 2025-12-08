#!/bin/bash
# random-wallpaper-loop.sh

# Folder containing wallpapers
WALLPAPER_DIR="$HOME/Pictures/wallpapers"

#kitty
KITTY_CONFIG="$HOME/.cache/wal/colors-kitty.conf"

# Endless loop
while true; do
    # Pick a random wallpaper
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)

    # Apply the wallpaper with swww
    swww img "$WALLPAPER" --transition-fps 60 --transition-step 255 --transition-type any

    # Generate a color scheme with pywal
    wal -i "$WALLPAPER" --backend wal 

    # Export pywal colors to a Kitty config for persistence
    #wal -n -o "$KITTY_CONFIG"

    # Reload all running Kitty terminals
    if command -v kitty &>/dev/null; then
        kitty @ set-colors --all "$KITTY_CONFIG" 2>/dev/null || true
    fi

    # Wait 3 minutes
    sleep 180
done 

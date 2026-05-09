#!/usr/bin/env bash
# Fetch album art URL from playerctl and cache locally
CACHE="/tmp/eww-album-art.jpg"
DEFAULT="$HOME/dotfiles/eww/assets/music-default.png"

URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

if [[ -z "$URL" ]]; then
    echo "${DEFAULT}"
    exit 0
fi

if [[ "$URL" == file://* ]]; then
    echo "${URL#file://}"
    exit 0
fi

# Remote URL — download and cache
if curl -sfL "$URL" -o "$CACHE" 2>/dev/null; then
    echo "$CACHE"
else
    echo "${DEFAULT}"
fi

#!/usr/bin/env bash
# Outputs JSON with current track metadata. Used by eww deflisten via --follow.
# Falls back to a "no media" object when no player is active.

format='{"status":"{{status}}","title":"{{markup_escape(title)}}","artist":"{{markup_escape(artist)}}","album":"{{markup_escape(album)}}","length":{{mpris:length}}}'

emit_idle() {
  printf '{"status":"Stopped","title":"","artist":"","album":"","length":0}\n'
}

# Initial state
playerctl metadata --format "$format" 2>/dev/null || emit_idle

# Follow changes
exec playerctl --follow metadata --format "$format" 2>/dev/null

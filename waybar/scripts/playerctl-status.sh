#!/usr/bin/env bash
# Waybar play/pause module — outputs JSON with icon based on playerctl status.

status=$(playerctl status 2>/dev/null)

case "$status" in
  Playing)
    printf '{"text":"","alt":"playing","class":"playing","tooltip":"Pause"}\n'
    ;;
  Paused)
    printf '{"text":"","alt":"paused","class":"paused","tooltip":"Play"}\n'
    ;;
  *)
    printf '{"text":"","alt":"stopped","class":"stopped","tooltip":"No media"}\n'
    ;;
esac

#!/usr/bin/env bash
set -e

PLAYERCTL_PATH="$(nix eval --raw nixpkgs#playerctl)"

export GI_TYPELIB_PATH="$PLAYERCTL_PATH/lib/girepository-1.0"
export LD_LIBRARY_PATH="$PLAYERCTL_PATH/lib:${LD_LIBRARY_PATH}"

exec python3 ~/dotfiles/hypr/scripts/mediaplayer.py "$@"

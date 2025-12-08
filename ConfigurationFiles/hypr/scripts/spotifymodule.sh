#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
waybar-mpris --autofocus | while IFS= read -r line; do
    # Extract JSON fields safely
    tooltip=$(echo "$line" | perl -0ne 'print $1 if /"tooltip":"(.*?)"/s')
    tooltip=$(echo -e "$tooltip" | tr -d '\r')
    song=$(echo "$tooltip" | sed -n '1p')
    artist=$(echo "$tooltip" | sed -n '2s/^by //p')

    # Extract play/pause symbol
    symbol=$(echo "$line" | perl -nle 'print $1 if /"class":"(.*?)"/')

    # Map class to symbol
    if [[ "$symbol" == "playing" ]]; then
        symbol="▶"
    elif [[ "$symbol" == "paused" ]]; then
        symbol="⏸"
    else
        symbol="▶"
    fi

    # Output artist first
    [[ -n $song && -n $artist ]] && echo "$symbol $artist - $song"
done

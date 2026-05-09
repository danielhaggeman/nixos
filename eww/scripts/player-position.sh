#!/usr/bin/env bash
# Outputs current player position as a percentage (0-100) and formatted times.
# Polled by eww (defpoll). Outputs JSON: {"pct":N,"pos":"M:SS","len":"M:SS"}

fmt() {
  local total_seconds=${1%.*}
  if [ -z "$total_seconds" ] || [ "$total_seconds" -lt 0 ]; then
    printf "0:00"
    return
  fi
  printf "%d:%02d" $((total_seconds / 60)) $((total_seconds % 60))
}

position=$(playerctl position 2>/dev/null || echo 0)
length_us=$(playerctl metadata mpris:length 2>/dev/null || echo 0)
length=$(awk -v l="$length_us" 'BEGIN{printf "%.0f", l/1000000}')

if [ "$length" -gt 0 ] 2>/dev/null; then
  pct=$(awk -v p="$position" -v l="$length" 'BEGIN{printf "%.1f", (p/l)*100}')
else
  pct=0
fi

printf '{"pct":%s,"pos":"%s","len":"%s"}\n' "$pct" "$(fmt "$position")" "$(fmt "$length")"

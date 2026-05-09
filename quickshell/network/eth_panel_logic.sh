#!/usr/bin/env bash
# eth_panel_logic.sh — NetworkManager ethernet connection manager
# Usage: eth_panel_logic.sh <command> [args]

CMD="$1"

case "$CMD" in
  list-connections)
    active_uuid=$(nmcli -t -f UUID,DEVICE con show --active 2>/dev/null | grep -E "eno|eth|enp" | head -1 | cut -d: -f1)
    nmcli -t -f NAME,UUID,TYPE con show 2>/dev/null | grep ":802-3-ethernet:" | while IFS=: read -r name uuid type; do
      is_active="false"
      [[ "$uuid" == "$active_uuid" ]] && is_active="true"
      ip_info=$(nmcli -t -f ipv4.addresses con show "$uuid" 2>/dev/null | cut -d: -f2- | tr -d ' ')
      gw_info=$(nmcli -t -f ipv4.gateway con show "$uuid" 2>/dev/null | cut -d: -f2- | tr -d ' ')
      echo "${name}|${ip_info}|${gw_info}|${is_active}"
    done
    ;;

  apply-static)
    CONN_NAME="$2"
    IP_PREFIX="$3"
    GATEWAY="$4"
    DNS1="${5:-1.1.1.1}"
    DNS2="${6:-8.8.8.8}"
    nmcli con mod "$CONN_NAME" \
      ipv4.method manual \
      ipv4.addresses "$IP_PREFIX" \
      ipv4.gateway "$GATEWAY" \
      ipv4.dns "$DNS1 $DNS2"
    nmcli con up "$CONN_NAME" && echo "applied" || echo "error"
    ;;

  apply-dhcp)
    CONN_NAME="$2"
    nmcli con mod "$CONN_NAME" \
      ipv4.method auto \
      ipv4.addresses "" \
      ipv4.gateway "" \
      ipv4.dns ""
    nmcli con up "$CONN_NAME" && echo "applied" || echo "error"
    ;;
esac

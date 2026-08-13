#!/usr/bin/env bash
# monitor.sh — Real-time system monitoring dashboard
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

mkdir -p "${SCRIPT_DIR}/${LOG_DIR}" "${SCRIPT_DIR}/${REPORT_DIR}"

# ANSI Color Constants
RST="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"
BG_RED="\033[41m"
BG_YELLOW="\033[43m"
BG_GREEN="\033[42m"

color_by_threshold() {
  local val=$1 warn=$2 crit=$3
  if (( $(echo "$val >= $crit" | bc -l) )); then
    echo -e "$RED"
  elif (( $(echo "$val >= $warn" | bc -l) )); then
    echo -e "$YELLOW"
  else
    echo -e "$GREEN"
  fi
}

status_label() {
  local val=$1 warn=$2 crit=$3
  if (( $(echo "$val >= $crit" | bc -l) )); then
    echo -e "${BG_RED} CRITICAL ${RST}"
  elif (( $(echo "$val >= $warn" | bc -l) )); then
    echo -e "${BG_YELLOW} WARNING  ${RST}"
  else
    echo -e "${BG_GREEN} NORMAL   ${RST}"
  fi
}

draw_bar() {
  local pct=${1%.*}
  # Prevent bar logic breaking if pct is empty or non-numeric
  [[ -z "$pct" || ! "$pct" =~ ^[0-9]+$ ]] && pct=0
  
  local filled=$(( pct * 30 / 100 ))
  local empty=$(( 30 - filled ))
  printf '['
  for ((i=0; i<filled; i++)); do printf '█'; done
  for ((i=0; i<empty; i++)); do printf '░'; done
  printf ']'
}

get_cpu_usage() {
  local snap1
  snap1=$(awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat 2>/dev/null)
  local idle1=$(echo $snap1 | awk '{print $4}')
  local total1=$(echo $snap1 | awk '{print $1+$2+$3+$4+$5+$6+$7}')

  sleep 1

  local snap2
  snap2=$(awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat 2>/dev/null)
  local idle2=$(echo $snap2 | awk '{print $4}')
  local total2=$(echo $snap2 | awk '{print $1+$2+$3+$4+$5+$6+$7}')

  local dtotal=$((total2-total1))
  local didle=$((idle2-idle1))

  if (( dtotal > 0 )); then
    printf "%.1f\n" "$(echo "scale=1; 100*($dtotal-$didle)/$dtotal" | bc -l)"
  else
    echo "0.0"
  fi
}

get_memory_usage() {
  local mem_info
  mem_info=$(free -m 2>/dev/null | awk '/^Mem/{print $2,$3}')

  local total
  local used
  total=$(echo $mem_info | awk '{print $1}')
  used=$(echo $mem_info | awk '{print $2}')

  if [[ -n "$total" && "$total" -gt 0 ]]; then
    local pct
    pct=$(echo "scale=1; $used/$total*100" | bc -l)
    echo "$pct|$used|$total"
  else
    echo "0.0|0|0"
  fi
}

get_disk_usage() {
  local disk_info
  disk_info=$(df -h / | awk 'NR==2{print $5,$3,$2}')

  local pct
  local used
  local total
  pct=$(echo $disk_info | awk '{print $1}' | tr -d '%')
  used=$(echo $disk_info | awk '{print $2}')
  total=$(echo $disk_info | awk '{print $3}')

  echo "$pct|$used|$total"
}

get_load_average() {
  local load
  load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.00")
  echo "$load"
}

get_network_speed() {
  local interface
  interface=$(ip route 2>/dev/null | awk '/default/{print $5}' | head -1)
  [[ -z "$interface" ]] && interface="eth0"

  local rx1=0 tx1=0 rx2=0 tx2=0
  if [[ -f "/sys/class/net/${interface}/statistics/rx_bytes" ]]; then
    rx1=$(cat "/sys/class/net/${interface}/statistics/rx_bytes")
    tx1=$(cat "/sys/class/net/${interface}/statistics/tx_bytes")
  fi

  sleep 1

  if [[ -f "/sys/class/net/${interface}/statistics/rx_bytes" ]]; then
    rx2=$(cat "/sys/class/net/${interface}/statistics/rx_bytes")
    tx2=$(cat "/sys/class/net/${interface}/statistics/tx_bytes")
  fi

  local rx_speed=$(( (rx2-rx1)/1024 ))
  local tx_speed=$(( (tx2-tx1)/1024 ))

  echo "$rx_speed|$tx_speed"
}

get_network_connections() {
  local connections
  connections=$(ss -tun 2>/dev/null | tail -n +2 | wc -l)
  echo "$connections"
}

get_error_rate() {
  local errors
  errors=$(journalctl --since "5 min ago" 2>/dev/null | grep -ic "error\|fail\|critical" || true)
  echo "${errors:-0}"
}
get_top_processes() {
  # Clean output without headers for sleek visual presentation
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu --no-headers 2>/dev/null | head -5
}

get_tcp_retransmissions() {
  local retrans
  retrans=$(awk '/^Tcp/{print $13}' /proc/net/snmp 2>/dev/null | tail -1)
  echo "${retrans:-0}"
}

get_disk_io() {
  local io_info
  io_info=$(iostat -d 2>/dev/null | grep -v "^$" | tail -1)

  local read_speed
  local write_speed
  read_speed=$(echo $io_info | awk '{print $3}')
  write_speed=$(echo $io_info | awk '{print $4}')

  echo "${read_speed:-0.00}|${write_speed:-0.00}"
}

trigger_alerts() {
  bash "${SCRIPT_DIR}/alerts.sh" "$1" "$2" "$3" "$4" &
}

log_health() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$ts CPU=$1% MEM=$2% DISK=$3% LOAD=$4" >> "${SCRIPT_DIR}/${HEALTH_LOG}"
}

render_dashboard() {
  clear

  # ── Header ──────────────────────────────────────
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════╗"
  echo "║       Linux System Monitor               ║"
  echo "║       Host: $(hostname)                  ║"
  echo "║       Time: $(date '+%Y-%m-%d %H:%M:%S') ║"
  echo "╚══════════════════════════════════════════╝"
  echo -e "${RST}"

  # ── CPU ─────────────────────────────────────────
  local cpu
  cpu=$(get_cpu_usage)
  local col
  col=$(color_by_threshold "$cpu" "$CPU_WARN" "$CPU_CRIT")
  echo -e "${BOLD}CPU Usage${RST}"
  echo -en "  ${col}"
  draw_bar "$cpu"
  echo -e " ${cpu}% ${RST} $(status_label "$cpu" "$CPU_WARN" "$CPU_CRIT")"
  echo ""

  # ── Memory ──────────────────────────────────────
  local mem_raw mem_pct mem_used mem_total
  mem_raw=$(get_memory_usage)
  mem_pct=$(echo $mem_raw | cut -d'|' -f1)
  mem_used=$(echo $mem_raw | cut -d'|' -f2)
  mem_total=$(echo $mem_raw | cut -d'|' -f3)
  col=$(color_by_threshold "$mem_pct" "$MEMORY_WARN" "$MEMORY_CRIT")
  echo -e "${BOLD}Memory Usage${RST}  (${mem_used}MB / ${mem_total}MB)"
  echo -en "  ${col}"
  draw_bar "$mem_pct"
  echo -e " ${mem_pct}% ${RST} $(status_label "$mem_pct" "$MEMORY_WARN" "$MEMORY_CRIT")"
  echo ""

  # ── Disk Usage ──────────────────────────────────
  local disk_raw disk_pct disk_used disk_total
  disk_raw=$(get_disk_usage)
  disk_pct=$(echo $disk_raw | cut -d'|' -f1)
  disk_used=$(echo $disk_raw | cut -d'|' -f2)
  disk_total=$(echo $disk_raw | cut -d'|' -f3)
  col=$(color_by_threshold "$disk_pct" "$DISK_WARN" "$DISK_CRIT")
  echo -e "${BOLD}Disk Usage  /  ${RST}  (${disk_used} / ${disk_total})"
  echo -en "  ${col}"
  draw_bar "$disk_pct"
  echo -e " ${disk_pct}% ${RST} $(status_label "$disk_pct" "$DISK_WARN" "$DISK_CRIT")"
  echo ""

  # ── Disk I/O ────────────────────────────────────
  local io_raw io_read io_write
  io_raw=$(get_disk_io)
  io_read=$(echo $io_raw | cut -d'|' -f1)
  io_write=$(echo $io_raw | cut -d'|' -f2)
  echo -e "${BOLD}Disk I/O${RST}"
  echo -e "  Read: ${CYAN}${io_read} KB/s${RST}  Write: ${CYAN}${io_write} KB/s${RST}"
  echo ""

  # ── Load Average ────────────────────────────────
  local load
  load=$(get_load_average)
  col=$(color_by_threshold "$load" "$LOAD_WARN" "$LOAD_CRIT")
  echo -e "${BOLD}Load Average${RST}"
  echo -e "  ${col}${load}${RST}  $(status_label "$load" "$LOAD_WARN" "$LOAD_CRIT")"
  echo ""

  # ── Network Speed ───────────────────────────────
  local net_raw net_rx net_tx
  net_raw=$(get_network_speed)
  net_rx=$(echo $net_raw | cut -d'|' -f1)
  net_tx=$(echo $net_raw | cut -d'|' -f2)
  echo -e "${BOLD}Network Speed${RST}"
  echo -e "  Download: ${CYAN}${net_rx} KB/s${RST}  Upload: ${CYAN}${net_tx} KB/s${RST}"
  echo ""

  # ── Network Connections ─────────────────────────
  local conns
  conns=$(get_network_connections)
  echo -e "${BOLD}Network Connections${RST}"
  echo -e "  Active: ${CYAN}${conns}${RST}"
  echo ""

  # ── Error Rate ──────────────────────────────────
  local errors
  errors=$(get_error_rate)
  col=$(color_by_threshold "$errors" "$NET_ERRORS_WARN" "$NET_ERRORS_CRIT")
  echo -e "${BOLD}System Errors (last 5 min)${RST}"
  echo -e "  ${col}${errors}${RST} errors found"
  echo ""

  # ── TCP Retransmissions ─────────────────────────
  local retrans
  retrans=$(get_tcp_retransmissions)
  col=$(color_by_threshold "$retrans" "$TCP_RETRANS_WARN" "$TCP_RETRANS_CRIT")
  echo -e "${BOLD}TCP Retransmissions${RST}"
  echo -e "  ${col}${retrans}${RST}  $(status_label "$retrans" "$TCP_RETRANS_WARN" "$TCP_RETRANS_CRIT")"
  echo ""

  # ── Top Processes ───────────────────────────────
  echo -e "${BOLD}Top Processes by CPU${RST}"
  printf "  %-8s %-15s %-6s %-6s\n" "PID" "COMMAND" "%CPU" "%MEM"
  get_top_processes | while IFS= read -r line; do
    echo "  $line"
  done
  echo ""

  # ── Footer ──────────────────────────────────────
  echo -e "  ${CYAN}Refreshing every ${REFRESH_INTERVAL}s — Press Ctrl+C to stop${RST}"
}

# ── Main Loop ───────────────────────────────────────

trap "echo -e '\n${GREEN}Dashboard stopped.${RST}'; exit 0" SIGINT SIGTERM

LAST_HEALTH_LOG=0
clear
while true; do
  render_dashboard

  cpu=$(get_cpu_usage)
  mem=$(get_memory_usage | cut -d'|' -f1)
  disk=$(get_disk_usage | cut -d'|' -f1)
  load=$(get_load_average)

  trigger_alerts "$cpu" "$mem" "$disk" "$load"

  now=$(date +%s)
  if (( now - LAST_HEALTH_LOG >= HEALTH_LOG_INTERVAL )); then
    log_health "$cpu" "$mem" "$disk" "$load"
    LAST_HEALTH_LOG=$now
  fi

  sleep "${REFRESH_INTERVAL}"
done

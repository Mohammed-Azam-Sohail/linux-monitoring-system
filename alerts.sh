#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "$0")/config.cfg"

CPU="${1:-0}"
MEM="${2:-0}"
DISK="${3:-0}"
LOAD="${4:-0}"

ALERT_FILE="$(dirname "$0")/${ALERT_LOG}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

ALERTS_TRIGGERED=()

check_threshold() {
  local name=$1
  local val=$2
  local warn=$3
  local crit=$4

  if (( $(echo "$val >= $crit" | bc -l) )); then
    echo "[$TIMESTAMP] CRITICAL: $name = $val (warn=$warn, crit=$crit)" >> "$ALERT_FILE"
    ALERTS_TRIGGERED+=("CRITICAL: $name=$val")

  elif (( $(echo "$val >= $warn" | bc -l) )); then
    echo "[$TIMESTAMP] WARNING: $name = $val (warn=$warn, crit=$crit)" >> "$ALERT_FILE"
    ALERTS_TRIGGERED+=("WARNING: $name=$val")
  fi
}

check_threshold "CPU"    "$CPU"  "$CPU_WARN"    "$CPU_CRIT"
check_threshold "MEMORY" "$MEM"  "$MEMORY_WARN" "$MEMORY_CRIT"
check_threshold "DISK"   "$DISK" "$DISK_WARN"   "$DISK_CRIT"
check_threshold "LOAD"   "$LOAD" "$LOAD_WARN"   "$LOAD_CRIT"

if [[ "$EMAIL_ENABLED" == "true" && ${#ALERTS_TRIGGERED[@]} -gt 0 ]]; then
  if command -v mail &>/dev/null; then
    echo "Alerts on $(hostname) at $TIMESTAMP" | \
      mail -s "${EMAIL_SUBJECT_PREFIX} Alert" "$EMAIL_RECIPIENT"
  fi
fi

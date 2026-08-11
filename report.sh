#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "$0")/config.cfg"

mkdir -p "$(dirname "$0")/${REPORT_DIR}"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
REPORT_FILE="$(dirname "$0")/${REPORT_DIR}/report_${TIMESTAMP}.txt"

{
  echo "======================================"
  echo " Daily System Report"
  echo " Date: $(date)"
  echo " Host: $(hostname)"
  echo "======================================"
  echo ""

  echo "--- 1. Uptime ---"
  uptime
  echo ""

  echo "--- 2. CPU ---"
  cat /proc/stat | head -1
  echo ""

  echo "--- 3. Memory ---"
  free -h
  echo ""

  echo "--- 4. Disk ---"
  df -h
  echo ""

  echo "--- 5. Top 5 Processes ---"
  ps aux --sort=-%cpu | head -6
  echo ""

  echo "--- 6. Load Average ---"
  cat /proc/loadavg
  echo ""

  echo "--- 7. Network ---"
  ss -tun
  echo ""

  echo "--- 8. Error Summary ---"
  journalctl --since "today" 2>/dev/null | grep -ic "error\|fail" || true
  echo ""

  echo "--- 9. TCP Statistics ---"
  cat /proc/net/snmp | grep "^Tcp"
  echo ""

  echo "--- 10. Alert Summary ---"
  if [[ -f "$(dirname "$0")/${ALERT_LOG}" ]]; then
    grep "$(date '+%Y-%m-%d')" "$(dirname "$0")/${ALERT_LOG}" || echo "No alerts today."
  else
    echo "No alerts yet."
  fi

} > "$REPORT_FILE"

echo "Report saved: $REPORT_FILE"

# Compress report
if command -v zip &>/dev/null; then
  zip "${REPORT_FILE}.zip" "$REPORT_FILE" && rm "$REPORT_FILE"
elif command -v gzip &>/dev/null; then
  gzip "$REPORT_FILE"
fi

# Email with attachment logic
if [[ "$EMAIL_ENABLED" == "true" ]]; then
  if command -v mail &>/dev/null; then
    ATTACHMENT=""
    [[ -f "${REPORT_FILE}.zip" ]] && ATTACHMENT="${REPORT_FILE}.zip"
    [[ -f "${REPORT_FILE}.gz" ]] && ATTACHMENT="${REPORT_FILE}.gz"
    
    if [[ -n "$ATTACHMENT" ]]; then
      echo "Daily report attached." | mail -a "$ATTACHMENT" -s "${EMAIL_SUBJECT_PREFIX} Daily Report" "$EMAIL_RECIPIENT"
    else
      # Fallback to inline text if compression failed
      echo "Daily report attached." | mail -s "${EMAIL_SUBJECT_PREFIX} Daily Report" "$EMAIL_RECIPIENT" < "$REPORT_FILE"
    fi
  fi
fi

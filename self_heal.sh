#!/usr/bin/env bash
set -uo pipefail

# Load config
source "$(dirname "$0")/config.cfg"
mkdir -p "$(dirname "$0")/${LOG_DIR}"
# Log file
LOG="$(dirname "$0")/${SELF_HEAL_LOG}"

# Write to both screen and log file
log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# Check if systemctl exists
if ! command -v systemctl &>/dev/null; then
  log_msg "ERROR: systemctl not available. Exiting."
  exit 1
fi

# Check each critical service
for SERVICE in $CRITICAL_SERVICES; do

  # Skip if service doesn't exist on this system
  if ! systemctl list-unit-files | grep -q "^${SERVICE}"; then
    log_msg "SKIP: $SERVICE not found on this system."
    continue
  fi

  # Check if service is running
  if systemctl is-active --quiet "$SERVICE"; then
    log_msg "OK: $SERVICE is running."
  else
    log_msg "DOWN: $SERVICE is down. Attempting restart..."

    # Try restarting up to MAX_RESTART_RETRIES times
    SUCCESS=false
    for ((i=1; i<=MAX_RESTART_RETRIES; i++)); do
      sudo systemctl restart "$SERVICE"
      sleep 2
      if systemctl is-active --quiet "$SERVICE"; then
        log_msg "RECOVERED: $SERVICE restarted on attempt $i."
        SUCCESS=true
        break
      fi
    done

    # If all retries failed — send email
    if [[ "$SUCCESS" == "false" ]]; then
      log_msg "FAILED: Could not restart $SERVICE after $MAX_RESTART_RETRIES attempts."
      if [[ "$EMAIL_ENABLED" == "true" ]]; then
        if command -v mail &>/dev/null; then
          echo "Service $SERVICE failed on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')" | \
            mail -s "${EMAIL_SUBJECT_PREFIX} Service failure: $SERVICE" "$EMAIL_RECIPIENT"
        fi
      fi
    fi
  fi

done

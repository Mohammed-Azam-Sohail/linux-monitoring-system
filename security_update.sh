#!/usr/bin/env bash
set -uo pipefail

# Load config
source "$(dirname "$0")/config.cfg"

LOG="$(dirname "$0")/${SECURITY_LOG}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] Starting security update..." | tee -a "$LOG"

# Detect distro
DISTRO=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# Run security update based on distro
SUCCESS=true
UPDATE_OUTPUT=""

case "$DISTRO" in
  ubuntu|debian)
    if command -v unattended-upgrade &>/dev/null; then
      UPDATE_OUTPUT=$(sudo unattended-upgrade -d 2>&1) || SUCCESS=false
    else
      UPDATE_OUTPUT=$(sudo apt-get install --only-upgrade -y $(apt-get --just-print upgrade | awk '/-security/ {print $2}') 2>&1) || SUCCESS=false
    fi
    ;;
  rhel|centos|rocky|almalinux)
    UPDATE_OUTPUT=$(sudo yum update --security -y 2>&1) || SUCCESS=false
    ;;
  fedora)
    UPDATE_OUTPUT=$(sudo dnf update --security -y 2>&1) || SUCCESS=false
    ;;
  *)
    echo "[$TIMESTAMP] Unsupported distro: $DISTRO" | tee -a "$LOG"
    exit 0
    ;;
esac

# Log last 20 lines only
echo "$UPDATE_OUTPUT" | tail -20 >> "$LOG"

# Log result
if [[ "$SUCCESS" == "true" ]]; then
  echo "[$TIMESTAMP] Security update SUCCESS." | tee -a "$LOG"
else
  echo "[$TIMESTAMP] Security update FAILED." | tee -a "$LOG"
  if [[ "$EMAIL_ENABLED" == "true" ]]; then
    if command -v mail &>/dev/null; then
      echo "Security update failed on $(hostname)" | \
        mail -s "${EMAIL_SUBJECT_PREFIX} Security update FAILED" "$EMAIL_RECIPIENT"
    fi
  fi
fi

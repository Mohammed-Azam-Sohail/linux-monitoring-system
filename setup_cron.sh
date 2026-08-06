#!/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

MARKER_START="# LINUX-MONITORING-SYSTEM-START"
MARKER_END="# LINUX-MONITORING-SYSTEM-END"

NEW_CRONS="${MARKER_START}
*/5 * * * * bash ${SCRIPT_DIR}/alerts.sh >> ${SCRIPT_DIR}/logs/alerts.log 2>&1
*/5 * * * * bash ${SCRIPT_DIR}/self_heal.sh >> ${SCRIPT_DIR}/logs/self_heal.log 2>&1
59 23 * * * bash ${SCRIPT_DIR}/report.sh >> ${SCRIPT_DIR}/logs/report.log 2>&1
0 0 * * * bash ${SCRIPT_DIR}/log_rotation.sh >> ${SCRIPT_DIR}/logs/rotation.log 2>&1
0 2 * * 0 bash ${SCRIPT_DIR}/maintenance.sh >> ${SCRIPT_DIR}/logs/maintenance.log 2>&1
0 3 * * 0 bash ${SCRIPT_DIR}/security_update.sh >> ${SCRIPT_DIR}/logs/security.log 2>&1
${MARKER_END}"

# Remove old entries if exist
CURRENT=$(crontab -l 2>/dev/null | sed "/${MARKER_START}/,/${MARKER_END}/d")

# Install new entries
echo -e "${CURRENT}\n${NEW_CRONS}" | crontab -

echo "Cron jobs installed successfully."
echo "Run 'crontab -l' to verify."
echo ""
echo "To remove all cron jobs run:"
echo "crontab -l | sed '/LINUX-MONITORING-SYSTEM-START/,/LINUX-MONITORING-SYSTEM-END/d' | crontab -"

#!/usr/bin/bash
set -euo pipefail

# Use absolute path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${SCRIPT_DIR}/logs"
MARKER_START="# LINUX-MONITORING-SYSTEM-START"
MARKER_END="# LINUX-MONITORING-SYSTEM-END"

NEW_CRONS="${MARKER_START}
*/5 * * * * bash -c 'source ${SCRIPT_DIR}/config.cfg; CPU=\$(top -bn1 | awk \"/Cpu/ {print \\\$2}\"); MEM=\$(free | awk \"/Mem:/ {print \\\$3/\\\$2 * 100.0}\"); DISK=\$(df -P / | awk \"END{print substr(\\\$5,1,length(\\\$5)-1)}\"); LOAD=\$(awk \"{print \\\$1}\" /proc/loadavg); bash ${SCRIPT_DIR}/alerts.sh \"\$CPU\" \"\$MEM\" \"\$DISK\" \"\$LOAD\"' >> ${SCRIPT_DIR}/logs/alerts.log 2>&1
*/5 * * * * bash ${SCRIPT_DIR}/self_heal.sh >> ${SCRIPT_DIR}/logs/self_heal.log 2>&1
59 23 * * * bash ${SCRIPT_DIR}/report.sh >> ${SCRIPT_DIR}/logs/report.log 2>&1
0 0 * * * bash ${SCRIPT_DIR}/log_rotation.sh >> ${SCRIPT_DIR}/logs/rotation.log 2>&1
0 2 * * 0 bash ${SCRIPT_DIR}/maintenance.sh >> ${SCRIPT_DIR}/logs/maintenance.log 2>&1
0 3 * * 0 bash ${SCRIPT_DIR}/security_update.sh >> ${SCRIPT_DIR}/logs/security.log 2>&1
${MARKER_END}"

CURRENT=$(crontab -l 2>/dev/null || true)
CURRENT=$(printf '%s\n' "$CURRENT" | sed "/${MARKER_START}/,/${MARKER_END}/d")

printf '%s\n%s\n' "$CURRENT" "$NEW_CRONS" | crontab -

#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "$0")/config.cfg"
mkdir -p "$(dirname "$0")/${LOG_DIR}" "$(dirname "$0")/${REPORT_DIR}"
LOG_PATH="$(dirname "$0")/${LOG_DIR}"
REPORT_PATH="$(dirname "$0")/${REPORT_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting log rotation..."

# Phase 1: Delete old logs
find "$LOG_PATH" -name "*.log" -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null
echo "  Deleted logs older than ${LOG_RETENTION_DAYS} days."

# Phase 2: Compress large logs
for f in "$LOG_PATH"/*.log; do
  if [[ -f "$f" ]]; then
    size=$(stat -c%s "$f")
    limit=$(( LOG_MAX_SIZE_MB * 1048576 ))
    if [ "$size" -gt "$limit" ]; then
      gzip "$f"
      echo "  Compressed: $f"
    fi
  fi
done

# Phase 3: Prune excess rotated files
for family in health_history alerts self_heal security_update; do
  count=0
  while IFS= read -r -d '' f; do
    count=$((count+1))
    if [ "$count" -gt "$MAX_ROTATED_FILES" ]; then
      rm -f "$f"
      echo "  Pruned: $f"
    fi
  done < <(find "$LOG_PATH" -name "${family}*.gz" -printf '%T@ %p\0' 2>/dev/null | sort -zrn | sed -z 's/^[^ ]* //')
done

# Phase 4: Clean old reports
find "$REPORT_PATH" -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null
echo "  Cleaned old reports."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotation complete."

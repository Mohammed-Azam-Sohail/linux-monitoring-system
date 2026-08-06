#!/usr/bin/bash
set -uo pipefail

# Load config
source "$(dirname "$0")/config.cfg"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] Starting weekly maintenance..."

# ── 1. System Package Update ──────────────────────
if command -v apt-get &>/dev/null; then
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get autoremove -y

elif command -v yum &>/dev/null; then
  sudo yum update -y
  sudo yum autoremove -y

elif command -v dnf &>/dev/null; then
  sudo dnf update -y
  sudo dnf autoremove -y

elif command -v pacman &>/dev/null; then
  sudo pacman -Syu --noconfirm

else
  echo "No supported package manager found."
fi

echo "  Package update done."

# ── 2. Temporary File Cleanup ─────────────────────
find /tmp -mtime +7 -delete 2>/dev/null
find /var/tmp -mtime +7 -delete 2>/dev/null
rm -rf ~/.cache/thumbnails/* 2>/dev/null

if command -v journalctl &>/dev/null; then
  sudo journalctl --vacuum-time=7d
fi

echo "  Temp files cleaned."

# ── 3. Log Rotation ───────────────────────────────
if [[ -x "$(dirname "$0")/log_rotation.sh" ]]; then
  bash "$(dirname "$0")/log_rotation.sh"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Weekly maintenance complete."

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/run/oneapi_bridge.pid"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
LAUNCHD_NAME="com.openclaw.cosyvoice.bridge"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
  systemctl --no-pager --full status "${SERVICE_NAME}"
  exit $?
fi

if command -v launchctl >/dev/null 2>&1 && [ -f "$HOME/Library/LaunchAgents/${LAUNCHD_NAME}.plist" ]; then
  launchctl list | grep -F "${LAUNCHD_NAME}" || true
  exit 0
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "running (pid $(cat "$PID_FILE"))"
  exit 0
fi

echo "not running"
exit 1

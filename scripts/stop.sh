#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/run/oneapi_bridge.pid"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
LAUNCHD_NAME="com.openclaw.cosyvoice.bridge"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
  sudo systemctl stop "${SERVICE_NAME}"
  echo "stopped systemd service: ${SERVICE_NAME}"
  exit 0
fi

if command -v launchctl >/dev/null 2>&1 && [ -f "$HOME/Library/LaunchAgents/${LAUNCHD_NAME}.plist" ]; then
  launchctl stop "${LAUNCHD_NAME}" || true
  echo "stopped launchd service: ${LAUNCHD_NAME}"
  exit 0
fi

if [ ! -f "$PID_FILE" ]; then
  echo "not running (pid file missing)"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if ! kill -0 "$PID" 2>/dev/null; then
  echo "not running (stale pid $PID)"
  rm -f "$PID_FILE"
  exit 0
fi

kill "$PID"
for _ in $(seq 1 20); do
  if kill -0 "$PID" 2>/dev/null; then
    sleep 0.2
  else
    break
  fi
done

if kill -0 "$PID" 2>/dev/null; then
  echo "process still running, sending SIGKILL"
  kill -9 "$PID" || true
fi

rm -f "$PID_FILE"

echo "stopped"

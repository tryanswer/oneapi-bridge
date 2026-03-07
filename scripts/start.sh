#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT_DIR/oneapi_bridge"
PID_FILE="$ROOT_DIR/run/oneapi_bridge.pid"
LOG_FILE="$ROOT_DIR/logs/server.log"
PORT="${PORT:-8090}"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
LAUNCHD_NAME="com.openclaw.cosyvoice.bridge"

if [[ "$PORT" == :* ]]; then
  ADDR="$PORT"
else
  ADDR=":$PORT"
fi

if [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN"
  echo "run: $ROOT_DIR/scripts/install.sh"
  exit 1
fi

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/run"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
  sudo systemctl start "${SERVICE_NAME}"
  sudo systemctl --no-pager --full status "${SERVICE_NAME}"
  exit 0
fi

if command -v launchctl >/dev/null 2>&1 && [ -f "$HOME/Library/LaunchAgents/${LAUNCHD_NAME}.plist" ]; then
  launchctl start "${LAUNCHD_NAME}"
  launchctl list | grep -F "${LAUNCHD_NAME}" || true
  exit 0
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running (pid $(cat "$PID_FILE"))"
  exit 0
fi

if [ -f "$PID_FILE" ]; then
  rm -f "$PID_FILE"
fi

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

if [ -z "${DASHSCOPE_API_KEY:-}" ]; then
  echo "missing DASHSCOPE_API_KEY"
  echo "set it in environment or $ROOT_DIR/.env before starting"
  exit 1
fi

touch "$LOG_FILE"

nohup "$BIN" -addr "$ADDR" >> "$LOG_FILE" 2>&1 &

PID="$!"
echo "$PID" > "$PID_FILE"

sleep 1

if ! kill -0 "$PID" 2>/dev/null; then
  echo "start failed, process exited early"
  rm -f "$PID_FILE"
  tail -n 20 "$LOG_FILE" 2>/dev/null || true
  exit 1
fi

echo "started pid $PID on $ADDR"
echo "log file: $LOG_FILE"

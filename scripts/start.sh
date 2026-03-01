#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT_DIR/oneapi_bridge"
PID_FILE="$ROOT_DIR/run/oneapi_bridge.pid"
LOG_FILE="$ROOT_DIR/logs/server.log"
PORT="${PORT:-8090}"
ADDR=":$PORT"

if [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN"
  echo "run: $ROOT_DIR/scripts/install.sh"
  exit 1
fi

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/run"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "already running (pid $(cat "$PID_FILE"))"
  exit 0
fi

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

nohup "$BIN" -addr "$ADDR" >> "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"

echo "started pid $(cat "$PID_FILE") on $ADDR"

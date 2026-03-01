#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/run/openclaw_bridge.pid"

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

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT_DIR/openclaw_bridge"
PORT="${PORT:-8090}"
ADDR=":$PORT"

cd "$ROOT_DIR"

if [ ! -x "$BIN" ]; then
  echo "binary missing, building..."
  go build -o openclaw_bridge .
fi

DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY}" \
  "$BIN" -addr "$ADDR"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/run"

go mod tidy
go build -o oneapi_bridge .

echo "built: $ROOT_DIR/oneapi_bridge"

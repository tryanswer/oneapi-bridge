#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

cd "$ROOT_DIR"

load_env
ensure_runtime_dirs

go mod tidy
go build -o oneapi_bridge .

echo "built: $BIN"

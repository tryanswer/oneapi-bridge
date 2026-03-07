#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

curl -fsS "http://127.0.0.1:${PORT}/healthz"

#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

if has_systemd_service; then
  systemctl --no-pager --full status "${SERVICE_NAME}"
  exit $?
fi

if has_launchd_service; then
  if launchctl list | grep -F "${LAUNCHD_NAME}"; then
    exit 0
  fi
  echo "not running"
  exit 1
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "running (pid $(cat "$PID_FILE"))"
  exit 0
fi

echo "not running"
exit 1

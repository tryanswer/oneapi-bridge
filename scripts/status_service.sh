#!/usr/bin/env bash
set -euo pipefail

if command -v systemctl >/dev/null 2>&1; then
  systemctl status --no-pager oneapi_bridge
  exit 0
fi

if command -v launchctl >/dev/null 2>&1; then
  launchctl list | grep -F com.openclaw.cosyvoice.bridge || true
  exit 0
fi

echo "no supported service manager found (systemd/launchd)"
exit 1

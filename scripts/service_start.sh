#!/usr/bin/env bash
set -euo pipefail

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl start openclaw_bridge
  sudo systemctl status --no-pager openclaw_bridge
  exit 0
fi

if command -v launchctl >/dev/null 2>&1; then
  launchctl start com.openclaw.cosyvoice.bridge
  launchctl list | grep -F com.openclaw.cosyvoice.bridge || true
  exit 0
fi

echo "no supported service manager found (systemd/launchd)"
exit 1

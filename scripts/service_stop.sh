#!/usr/bin/env bash
set -euo pipefail

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl stop openclaw_bridge
  exit 0
fi

if command -v launchctl >/dev/null 2>&1; then
  launchctl stop com.openclaw.cosyvoice.bridge
  exit 0
fi

echo "no supported service manager found (systemd/launchd)"
exit 1

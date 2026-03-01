#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="openclaw_bridge"

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl disable --now "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  sudo systemctl daemon-reload
  echo "removed systemd service: $SERVICE_NAME"
  exit 0
fi

if command -v launchctl >/dev/null 2>&1; then
  PLIST="$HOME/Library/LaunchAgents/com.openclaw.cosyvoice.bridge.plist"
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST"
  echo "removed launchd service: com.openclaw.cosyvoice.bridge"
  exit 0
fi

echo "no supported service manager found (systemd/launchd)"
exit 1

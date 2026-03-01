#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT_DIR/openclaw_bridge"
PORT="${PORT:-8090}"
SERVICE_NAME="openclaw_bridge"

if [ ! -x "$BIN" ]; then
  echo "binary not found: $BIN"
  echo "run: $ROOT_DIR/scripts/install.sh"
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
  sudo bash -c "cat > '$SERVICE_FILE' <<'SERVICE_EOF'
[Unit]
Description=OpenClaw CosyVoice Bridge
After=network.target

[Service]
Type=simple
WorkingDirectory=$ROOT_DIR
EnvironmentFile=-$ROOT_DIR/.env
ExecStart=$BIN -addr :$PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE_EOF"
  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SERVICE_NAME"
  echo "installed systemd service: $SERVICE_NAME"
  exit 0
fi

if command -v launchctl >/dev/null 2>&1; then
  PLIST="$HOME/Library/LaunchAgents/com.openclaw.cosyvoice.bridge.plist"

  get_env() {
    local key="$1"
    local val=""
    if [ -f "$ROOT_DIR/.env" ]; then
      val=$(grep -E "^${key}=" "$ROOT_DIR/.env" | tail -n1 | sed -E "s/^${key}=//")
    fi
    if [ -z "$val" ]; then
      val="${!key:-}"
    fi
    echo "$val"
  }

  env_entries=""
  add_env() {
    local key="$1"
    local val="$2"
    if [ -z "$val" ]; then
      return
    fi
    env_entries="$env_entries\n    <key>${key}</key>\n    <string>${val}</string>"
  }

  add_env "DASHSCOPE_API_KEY" "$(get_env DASHSCOPE_API_KEY)"
  add_env "DASHSCOPE_WS_URL" "$(get_env DASHSCOPE_WS_URL)"
  add_env "DASHSCOPE_TIMEOUT" "$(get_env DASHSCOPE_TIMEOUT)"

  mkdir -p "$ROOT_DIR/logs"

  cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.openclaw.cosyvoice.bridge</string>
    <key>ProgramArguments</key>
    <array>
      <string>$BIN</string>
      <string>-addr</string>
      <string>:$PORT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$ROOT_DIR/logs/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$ROOT_DIR/logs/launchd.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>${env_entries}
    </dict>
  </dict>
</plist>
PLIST_EOF

  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  launchctl load "$PLIST"
  launchctl start com.openclaw.cosyvoice.bridge
  echo "installed launchd service: com.openclaw.cosyvoice.bridge"
  exit 0
fi

echo "no supported service manager found (systemd/launchd)"
exit 1

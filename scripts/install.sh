#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT_DIR/oneapi_bridge"
PORT="${PORT:-8090}"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
LAUNCHD_NAME="com.openclaw.cosyvoice.bridge"

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

install_systemd_service() {
  local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
  sudo bash -c "cat > '$service_file' <<'SERVICE_EOF'
[Unit]
Description=OpenClaw OneAPI Bridge
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
  sudo systemctl enable "$SERVICE_NAME"
  echo "installed systemd service: $SERVICE_NAME"
}

install_launchd_service() {
  local plist="$HOME/Library/LaunchAgents/${LAUNCHD_NAME}.plist"
  local env_entries=""
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

  mkdir -p "$ROOT_DIR/logs" "$HOME/Library/LaunchAgents"

  cat > "$plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${LAUNCHD_NAME}</string>
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

  launchctl unload "$plist" >/dev/null 2>&1 || true
  launchctl load "$plist"
  echo "installed launchd service: ${LAUNCHD_NAME}"
}

cd "$ROOT_DIR"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/run"

go mod tidy
go build -o oneapi_bridge .

echo "built: $BIN"

if command -v systemctl >/dev/null 2>&1; then
  install_systemd_service
elif command -v launchctl >/dev/null 2>&1; then
  install_launchd_service
fi

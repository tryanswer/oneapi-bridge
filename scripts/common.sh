#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT_DIR}/oneapi_bridge"
PID_FILE="${ROOT_DIR}/run/oneapi_bridge.pid"
LOG_FILE="${ROOT_DIR}/logs/server.log"
PORT="${PORT:-8090}"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
LAUNCHD_NAME="com.openclaw.cosyvoice.bridge"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_NAME}.plist"

if [[ "${PORT}" == :* ]]; then
  ADDR="${PORT}"
else
  ADDR=":${PORT}"
fi

load_env() {
  if [ -f "${ROOT_DIR}/.env" ]; then
    set -a
    . "${ROOT_DIR}/.env"
    set +a
  fi
}

ensure_runtime_dirs() {
  mkdir -p "${ROOT_DIR}/logs" "${ROOT_DIR}/run"
}

has_systemd_service() {
  command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"
}

has_launchd_service() {
  command -v launchctl >/dev/null 2>&1 && [ -f "${LAUNCHD_PLIST}" ]
}

get_env_value() {
  local key="$1"
  local val=""
  if [ -f "${ROOT_DIR}/.env" ]; then
    val=$(grep -E "^${key}=" "${ROOT_DIR}/.env" | tail -n1 | sed -E "s/^${key}=//")
  fi
  if [ -z "${val}" ]; then
    val="${!key:-}"
  fi
  echo "${val}"
}

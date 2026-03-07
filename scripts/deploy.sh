#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-aliyun}"
REMOTE_ROOT="${REMOTE_ROOT:-/root/openclaw/oneapi-bridge}"
REMOTE_BRANCH="${REMOTE_BRANCH:-}"
SERVICE_NAME="${SERVICE_NAME:-oneapi_bridge}"
REMOTE_HTTP_PROXY="${REMOTE_HTTP_PROXY:-http://127.0.0.1:7890}"
REMOTE_HTTPS_PROXY="${REMOTE_HTTPS_PROXY:-http://127.0.0.1:7890}"
REMOTE_ALL_PROXY="${REMOTE_ALL_PROXY:-socks5://127.0.0.1:7890}"

log() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

require_cmd ssh

log "Deploying openclaw-oneapi-bridge on ${REMOTE_HOST} via git sync"
ssh "${REMOTE_HOST}" \
  REMOTE_ROOT="${REMOTE_ROOT}" \
  REMOTE_BRANCH="${REMOTE_BRANCH}" \
  SERVICE_NAME="${SERVICE_NAME}" \
  REMOTE_HTTP_PROXY="${REMOTE_HTTP_PROXY}" \
  REMOTE_HTTPS_PROXY="${REMOTE_HTTPS_PROXY}" \
  REMOTE_ALL_PROXY="${REMOTE_ALL_PROXY}" \
  'bash -s' <<'REMOTE_SCRIPT'
set -euo pipefail

export http_proxy="${REMOTE_HTTP_PROXY}"
export https_proxy="${REMOTE_HTTPS_PROXY}"
export all_proxy="${REMOTE_ALL_PROXY}"

if [ ! -d "${REMOTE_ROOT}/.git" ]; then
  echo "Missing git repo on remote: ${REMOTE_ROOT}" >&2
  exit 1
fi

mkdir -p "${REMOTE_ROOT}/logs" "${REMOTE_ROOT}/run"

if [ -n "${REMOTE_BRANCH}" ]; then
  git -C "${REMOTE_ROOT}" fetch --all --prune
  git -C "${REMOTE_ROOT}" checkout "${REMOTE_BRANCH}"
  git -C "${REMOTE_ROOT}" pull --ff-only origin "${REMOTE_BRANCH}"
else
  CURRENT_BRANCH="$(git -C "${REMOTE_ROOT}" rev-parse --abbrev-ref HEAD)"
  git -C "${REMOTE_ROOT}" pull --ff-only origin "${CURRENT_BRANCH}"
fi

cd "${REMOTE_ROOT}"
"${REMOTE_ROOT}/scripts/install.sh"

if command -v systemctl >/dev/null 2>&1; then
  if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}\.service"; then
    "${REMOTE_ROOT}/scripts/service_install.sh"
  fi
  systemctl restart "${SERVICE_NAME}"
  systemctl --no-pager --full status "${SERVICE_NAME}"
else
  "${REMOTE_ROOT}/scripts/stop.sh" || true
  "${REMOTE_ROOT}/scripts/start.sh"
fi
REMOTE_SCRIPT

log "Deployment complete"

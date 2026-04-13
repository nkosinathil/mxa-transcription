#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/deploy/deploy.sh --role <app|python|sso> [--config <path>] [--rollback] [--non-interactive]

Options:
  --role             Target server role (required)
  --config           Env file with deployment values (default: scripts/deploy/.env)
  --rollback         Run rollback for role instead of setup
  --non-interactive  Disable prompts; require env/config values

Examples:
  sudo ./scripts/deploy/deploy.sh --role sso --config ./scripts/deploy/.env --non-interactive
  sudo ./scripts/deploy/deploy.sh --role app --config ./scripts/deploy/.env --rollback
EOF
}

ROLE=""
CONFIG_PATH="${SCRIPT_DIR}/.env"
ROLLBACK="false"
NON_INTERACTIVE_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --rollback)
      ROLLBACK="true"
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE_FLAG="--non-interactive"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${ROLE}" ]]; then
  err "--role is required"
  usage
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  err "Config file not found: ${CONFIG_PATH}"
  info "Copy scripts/deploy/env.example to scripts/deploy/.env and edit values."
  exit 1
fi

# shellcheck source=/dev/null
set -a
source "${CONFIG_PATH}"
set +a

# Derived defaults from common config entries.
SSO_SERVER_IP="${SSO_SERVER_IP:-192.168.1.59}"
PYTHON_SERVER_IP="${PYTHON_SERVER_IP:-192.168.1.90}"
APP_SERVER_IP="${APP_SERVER_IP:-192.168.1.66}"
DB_NAME="${DB_NAME:-transcription_db}"
DB_USER="${DB_USER:-transcription_user}"

KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-http://${SSO_SERVER_IP}:8080}"
PYTHON_API_BASE_URL="${PYTHON_API_BASE_URL:-http://${PYTHON_SERVER_IP}:8000}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-${PYTHON_SERVER_IP}:9000}"

if [[ -n "${SHARED_API_KEY:-}" ]]; then
  PYTHON_API_KEY="${PYTHON_API_KEY:-${SHARED_API_KEY}}"
  API_SECRET_KEY="${API_SECRET_KEY:-${SHARED_API_KEY}}"
fi

if [[ -z "${POSTGRES_DSN:-}" && -n "${DB_PASS:-}" ]]; then
  POSTGRES_DSN="postgresql://${DB_USER}:${DB_PASS}@${APP_SERVER_IP}:5432/${DB_NAME}"
fi

export KEYCLOAK_BASE_URL PYTHON_API_BASE_URL MINIO_ENDPOINT
export PYTHON_API_KEY API_SECRET_KEY POSTGRES_DSN DB_NAME DB_USER

if [[ "${ROLLBACK}" == "true" ]]; then
  exec "${SCRIPT_DIR}/rollback.sh" --role "${ROLE}" --config "${CONFIG_PATH}"
fi

case "${ROLE}" in
  app)
    exec "${SCRIPT_DIR}/setup-app-server.sh" ${NON_INTERACTIVE_FLAG}
    ;;
  python)
    exec "${SCRIPT_DIR}/setup-python-server.sh" ${NON_INTERACTIVE_FLAG}
    ;;
  sso)
    exec "${SCRIPT_DIR}/setup-sso-server.sh" ${NON_INTERACTIVE_FLAG}
    ;;
  *)
    err "Unsupported role: ${ROLE}"
    usage
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT_DIR}/scripts/lib/common.sh"

parse_non_interactive_flag "$@"
require_root

print_header "MXA Transcription - Python Server Setup"
info "Target role: Python API / Celery / Redis / MinIO"

DEFAULT_PY_DIR="/opt/mxa-transcription/python-backend"
DEFAULT_ENV_FILE="${DEFAULT_PY_DIR}/.env"
DEFAULT_SVC_USER="transcription"
DEFAULT_APP_HOST="0.0.0.0"
DEFAULT_APP_PORT="8000"

PY_DIR="${PY_DIR:-}"
ENV_FILE="${ENV_FILE:-}"
SERVICE_USER="${SERVICE_USER:-}"
APP_HOST="${APP_HOST:-}"
APP_PORT="${APP_PORT:-}"
API_SECRET_KEY="${API_SECRET_KEY:-}"
REDIS_URL="${REDIS_URL:-}"
POSTGRES_DSN="${POSTGRES_DSN:-}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"
CORS_ORIGINS="${CORS_ORIGINS:-}"
LOG_LEVEL="${LOG_LEVEL:-}"
DEBUG="${DEBUG:-}"

prompt_value PY_DIR "Python backend install directory" "${PY_DIR:-$DEFAULT_PY_DIR}"
prompt_value ENV_FILE "Python .env file path" "${ENV_FILE:-$DEFAULT_ENV_FILE}"
prompt_value SERVICE_USER "Service user to run API/worker" "${SERVICE_USER:-$DEFAULT_SVC_USER}"
prompt_value APP_HOST "FastAPI listen host" "${APP_HOST:-$DEFAULT_APP_HOST}"
prompt_value APP_PORT "FastAPI listen port" "${APP_PORT:-$DEFAULT_APP_PORT}"
prompt_value API_SECRET_KEY "Shared API key (must match php-app PYTHON_API_KEY)" "${API_SECRET_KEY}"
prompt_value REDIS_URL "Redis URL" "${REDIS_URL:-redis://localhost:6379/0}"
prompt_value POSTGRES_DSN "PostgreSQL DSN (python->app DB)" "${POSTGRES_DSN}"
prompt_value MINIO_ENDPOINT "MinIO endpoint" "${MINIO_ENDPOINT:-localhost:9000}"
prompt_value MINIO_ACCESS_KEY "MinIO access key" "${MINIO_ACCESS_KEY}"
prompt_secret MINIO_SECRET_KEY "MinIO secret key"
prompt_value CORS_ORIGINS "Allowed CORS origins (comma-separated, no spaces)" "${CORS_ORIGINS:-http://localhost}"
prompt_value LOG_LEVEL "Log level" "${LOG_LEVEL:-INFO}"
prompt_value DEBUG "Enable debug mode (true/false)" "${DEBUG:-false}"

require_env_vars API_SECRET_KEY POSTGRES_DSN MINIO_ACCESS_KEY MINIO_SECRET_KEY

print_header "Installing packages"
run_cmd apt-get update
run_cmd apt-get install -y python3 python3-venv python3-pip ffmpeg redis-server

print_header "Preparing service user and directories"
if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
  run_cmd useradd --system --create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

if [[ ! -d "${PY_DIR}" ]]; then
  warn "Python directory ${PY_DIR} not found."
  info "Copy repository's python-backend there before continuing."
  exit 1
fi

run_cmd mkdir -p "$(dirname "${ENV_FILE}")"
run_cmd chown -R "${SERVICE_USER}:${SERVICE_USER}" "${PY_DIR}"
run_cmd chmod 755 "${PY_DIR}"

print_header "Creating virtual environment and installing dependencies"
if [[ ! -d "${PY_DIR}/.venv" ]]; then
  run_cmd python3 -m venv "${PY_DIR}/.venv"
fi
run_cmd "${PY_DIR}/.venv/bin/pip" install --upgrade pip
run_cmd "${PY_DIR}/.venv/bin/pip" install -r "${PY_DIR}/requirements.txt"

print_header "Writing environment file"
if [[ ! -f "${ENV_FILE}" ]]; then
  run_cmd cp "${ROOT_DIR}/python-backend/.env.example" "${ENV_FILE}"
fi
set_env_var "${ENV_FILE}" "DEBUG" "${DEBUG}"
set_env_var "${ENV_FILE}" "LOG_LEVEL" "${LOG_LEVEL}"
set_env_var "${ENV_FILE}" "API_SECRET_KEY" "${API_SECRET_KEY}"
set_env_var "${ENV_FILE}" "REDIS_URL" "${REDIS_URL}"
set_env_var "${ENV_FILE}" "MINIO_ENDPOINT" "${MINIO_ENDPOINT}"
set_env_var "${ENV_FILE}" "MINIO_ACCESS_KEY" "${MINIO_ACCESS_KEY}"
set_env_var "${ENV_FILE}" "MINIO_SECRET_KEY" "${MINIO_SECRET_KEY}"
set_env_var "${ENV_FILE}" "POSTGRES_DSN" "${POSTGRES_DSN}"
set_env_var "${ENV_FILE}" "CORS_ALLOW_ORIGINS" "${CORS_ORIGINS}"
run_cmd chown "${SERVICE_USER}:${SERVICE_USER}" "${ENV_FILE}"
run_cmd chmod 640 "${ENV_FILE}"

print_header "Installing systemd units"
API_SERVICE_FILE="/etc/systemd/system/transcription-api.service"
WORKER_SERVICE_FILE="/etc/systemd/system/transcription-worker.service"

cat > "${API_SERVICE_FILE}" <<EOF
[Unit]
Description=MXA Transcription API
After=network.target redis-server.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${PY_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${PY_DIR}/.venv/bin/uvicorn app.main:app --host ${APP_HOST} --port ${APP_PORT} --workers 2 --log-level info
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

cat > "${WORKER_SERVICE_FILE}" <<EOF
[Unit]
Description=MXA Transcription Celery Worker
After=network.target redis-server.service transcription-api.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${PY_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${PY_DIR}/.venv/bin/celery -A app.core.celery_app worker --loglevel=info --concurrency=2 --queues=transcription --hostname=worker@%h
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

run_cmd systemctl daemon-reload
run_cmd systemctl enable --now redis-server
run_cmd systemctl enable --now transcription-api
run_cmd systemctl enable --now transcription-worker

print_header "Setup complete"
info "Python backend directory: ${PY_DIR}"
info "Environment file: ${ENV_FILE}"
info "API endpoint: http://${APP_HOST}:${APP_PORT}"
info "Run health check from app server:"
info "  curl -H \"X-Api-Key: <key>\" http://<python-host>:${APP_PORT}/api/health"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT_DIR}/scripts/lib/common.sh"

require_root

print_header "MXA Transcription - Python Server Setup"
info "Target role: Python API / Celery / Redis / MinIO"

DEFAULT_PY_DIR="/opt/mxa-transcription/python-backend"
DEFAULT_ENV_FILE="${DEFAULT_PY_DIR}/.env"
DEFAULT_SVC_USER="transcription"
DEFAULT_APP_HOST="0.0.0.0"
DEFAULT_APP_PORT="8000"

prompt_value PY_DIR "Python backend install directory" "$DEFAULT_PY_DIR"
prompt_value ENV_FILE "Python .env file path" "$DEFAULT_ENV_FILE"
prompt_value SERVICE_USER "Service user to run API/worker" "$DEFAULT_SVC_USER"
prompt_value APP_HOST "FastAPI listen host" "$DEFAULT_APP_HOST"
prompt_value APP_PORT "FastAPI listen port" "$DEFAULT_APP_PORT"

prompt_value API_SECRET_KEY "Shared API key (must match php-app PYTHON_API_KEY)" ""
while [[ -z "${API_SECRET_KEY}" ]]; do
  warn "API_SECRET_KEY is required."
  prompt_value API_SECRET_KEY "Shared API key (must match php-app PYTHON_API_KEY)" ""
done

prompt_value REDIS_URL "Redis URL" "redis://localhost:6379/0"
prompt_value POSTGRES_DSN "PostgreSQL DSN (python->app DB)" ""
while [[ -z "${POSTGRES_DSN}" ]]; do
  warn "POSTGRES_DSN is required."
  prompt_value POSTGRES_DSN "PostgreSQL DSN (python->app DB)" ""
done

prompt_value MINIO_ENDPOINT "MinIO endpoint" "localhost:9000"
prompt_value MINIO_ACCESS_KEY "MinIO access key" ""
while [[ -z "${MINIO_ACCESS_KEY}" ]]; do
  warn "MINIO_ACCESS_KEY is required."
  prompt_value MINIO_ACCESS_KEY "MinIO access key" ""
done

prompt_secret MINIO_SECRET_KEY "MinIO secret key"
while [[ -z "${MINIO_SECRET_KEY}" ]]; do
  warn "MINIO_SECRET_KEY is required."
  prompt_secret MINIO_SECRET_KEY "MinIO secret key"
done

prompt_value CORS_ORIGINS "Allowed CORS origins (comma-separated, no spaces)" "http://localhost"
prompt_value LOG_LEVEL "Log level" "INFO"
prompt_value DEBUG "Enable debug mode (true/false)" "false"

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

run_cmd chown -R "${SERVICE_USER}:${SERVICE_USER}" "${PY_DIR}"
run_cmd chmod 755 "${PY_DIR}"

print_header "Creating virtual environment and installing dependencies"
if [[ ! -d "${PY_DIR}/.venv" ]]; then
  run_cmd python3 -m venv "${PY_DIR}/.venv"
fi
run_cmd "${PY_DIR}/.venv/bin/pip" install --upgrade pip
run_cmd "${PY_DIR}/.venv/bin/pip" install -r "${PY_DIR}/requirements.txt"

print_header "Writing environment file"
run_cmd cp "${ROOT_DIR}/python-backend/.env.example" "${ENV_FILE}"
run_cmd sed -i "s|^DEBUG=.*|DEBUG=${DEBUG}|" "${ENV_FILE}"
run_cmd sed -i "s|^LOG_LEVEL=.*|LOG_LEVEL=${LOG_LEVEL}|" "${ENV_FILE}"
run_cmd sed -i "s|^API_SECRET_KEY=.*|API_SECRET_KEY=${API_SECRET_KEY}|" "${ENV_FILE}"
run_cmd sed -i "s|^REDIS_URL=.*|REDIS_URL=${REDIS_URL}|" "${ENV_FILE}"
run_cmd sed -i "s|^MINIO_ENDPOINT=.*|MINIO_ENDPOINT=${MINIO_ENDPOINT}|" "${ENV_FILE}"
run_cmd sed -i "s|^MINIO_ACCESS_KEY=.*|MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}|" "${ENV_FILE}"
run_cmd sed -i "s|^MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=${MINIO_SECRET_KEY}|" "${ENV_FILE}"
run_cmd sed -i "s|^POSTGRES_DSN=.*|POSTGRES_DSN=${POSTGRES_DSN}|" "${ENV_FILE}"
run_cmd sed -i "s|^ALLOWED_CORS_ORIGINS=.*|ALLOWED_CORS_ORIGINS=${CORS_ORIGINS}|" "${ENV_FILE}"
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

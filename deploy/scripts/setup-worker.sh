#!/usr/bin/env bash
# Install and configure backend API and worker systemd services.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-worker.sh
#
# Renders systemd units for Uvicorn and Celery using deployment variables, then
# enables and restarts them.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands systemctl

backup_file backend /etc/systemd/system/mxa-api.service
backup_file backend /etc/systemd/system/mxa-celery.service
render_template "${DEPLOY_ROOT}/systemd/mxa-api.service.template" /etc/systemd/system/mxa-api.service     APP_USER "${APP_USER}"     APP_GROUP "${APP_GROUP}"     BACKEND_APP_DIR "${BACKEND_APP_DIR}"     BACKEND_VENV_DIR "${BACKEND_VENV_DIR}"     PYTHON_ENV_FILE "${PYTHON_ENV_FILE}"     BACKEND_API_HOST "${BACKEND_API_HOST}"     BACKEND_API_PORT "${BACKEND_API_PORT}"     BACKEND_LOG_DIR "${BACKEND_LOG_DIR}"
render_template "${DEPLOY_ROOT}/systemd/mxa-celery.service.template" /etc/systemd/system/mxa-celery.service     APP_USER "${APP_USER}"     APP_GROUP "${APP_GROUP}"     BACKEND_APP_DIR "${BACKEND_APP_DIR}"     BACKEND_VENV_DIR "${BACKEND_VENV_DIR}"     PYTHON_ENV_FILE "${PYTHON_ENV_FILE}"     CELERY_CONCURRENCY "${CELERY_CONCURRENCY}"     BACKEND_LOG_DIR "${BACKEND_LOG_DIR}"
restart_service mxa-api
restart_service mxa-celery

log_success "Backend API and worker services configured"

#!/usr/bin/env bash
# Install backend dependencies and Python virtual environment.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-backend.sh
#
# Installs backend OS packages, creates the application user, provisions the
# virtualenv, installs Python requirements, ensures Redis is running, and writes
# the backend runtime env file from deployment variables.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands systemctl

apt_install ${BACKEND_PACKAGES}
ensure_user "${APP_USER}" "/bin/bash"
ensure_dir "${BACKEND_LOG_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "${BACKEND_LOG_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "${BACKEND_APP_DIR}"

if [[ ! -d "${BACKEND_VENV_DIR}" ]]; then
    run sudo -u "${APP_USER}" "${PYTHON_BIN}" -m venv "${BACKEND_VENV_DIR}"
fi

run sudo -u "${APP_USER}" "${BACKEND_VENV_DIR}/bin/pip" install --upgrade pip wheel
run sudo -u "${APP_USER}" "${BACKEND_VENV_DIR}/bin/pip" install -r "${BACKEND_APP_DIR}/python-backend/requirements.txt"
run sudo -u "${APP_USER}" "${BACKEND_VENV_DIR}/bin/pip" install -r "${BACKEND_APP_DIR}/requirements.txt"
write_python_runtime_env
run chown "${APP_USER}:${APP_GROUP}" "${PYTHON_ENV_FILE}"
run systemctl enable redis-server
run systemctl restart redis-server

log_success "Backend dependencies installed"

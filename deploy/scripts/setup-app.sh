#!/usr/bin/env bash
# Clone or update the application repository and bootstrap runtime env files.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-app.sh <frontend|backend>
#
# This script handles git checkout, revision tracking for rollback, and creating
# runtime .env files from repository templates when missing.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

ROLE="${1:-}"
case "${ROLE}" in frontend|backend) ;; *) die "Usage: $0 <frontend|backend>" ;; esac

require_root
require_commands git

clone_or_update_repo "${ROLE}"

if [[ "${ROLE}" == "frontend" ]]; then
    ensure_dir "${FRONTEND_APP_DIR}/php-app/storage/logs"
    ensure_dir "${FRONTEND_APP_DIR}/php-app/storage/uploads"
    bootstrap_env_file "${PHP_ENV_FILE}" "${FRONTEND_APP_DIR}/php-app/.env.example"
else
    ensure_dir "${BACKEND_LOG_DIR}"
    bootstrap_env_file "${PYTHON_ENV_FILE}" "${BACKEND_APP_DIR}/python-backend/.env.example"
fi

log_success "Application setup complete for role: ${ROLE}"

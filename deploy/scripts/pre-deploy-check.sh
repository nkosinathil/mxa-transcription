#!/usr/bin/env bash
# Validate deployment prerequisites before making changes on a target host.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/pre-deploy-check.sh <frontend|backend|keycloak|all>
#
# The script checks root access, required tools, configured variables, and the
# presence of the repository deployment assets needed by later scripts.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

ROLE="${1:-}"
[[ -n "${ROLE}" ]] || die "Usage: $0 <frontend|backend|keycloak|all>"
case "${ROLE}" in frontend|backend|keycloak|all) ;; *) die "Invalid role: ${ROLE}" ;; esac

require_root
require_commands bash git sed awk curl systemctl

[[ -d "${PROJECT_ROOT}/php-app" ]] || die "Repository path missing php-app/: ${PROJECT_ROOT}"
[[ -d "${PROJECT_ROOT}/python-backend" ]] || die "Repository path missing python-backend/: ${PROJECT_ROOT}"
[[ -f "${PROJECT_ROOT}/database/migrations/001_initial_schema.sql" ]] || die "Missing database migration file"
[[ -f "${DEPLOY_ROOT}/systemd/mxa-api.service.template" ]] || die "Missing deploy/systemd templates"
[[ -f "${DEPLOY_ROOT}/apache/mxa-transcription.conf.template" ]] || die "Missing Apache template"

validate_common() {
    [[ -n "${REPO_URL}" ]] || die "REPO_URL must be set"
    [[ -n "${DEPLOY_BRANCH}" ]] || die "DEPLOY_BRANCH must be set"
}

validate_frontend() {
    [[ -n "${FRONTEND_APP_DIR}" ]] || die "FRONTEND_APP_DIR must be set"
    [[ -n "${FRONTEND_SERVER_NAME}" ]] || die "FRONTEND_SERVER_NAME must be set"
    [[ -n "${DB_NAME}" ]] || die "DB_NAME must be set"
    [[ -n "${DB_USER}" ]] || die "DB_USER must be set"
    [[ -n "${DB_PASSWORD}" ]] || log_warn "DB_PASSWORD is empty"
    [[ -n "${PHP_ENV_FILE}" ]] || die "PHP_ENV_FILE must be set"
}

validate_backend() {
    [[ -n "${BACKEND_APP_DIR}" ]] || die "BACKEND_APP_DIR must be set"
    [[ -n "${BACKEND_VENV_DIR}" ]] || die "BACKEND_VENV_DIR must be set"
    [[ -n "${APP_USER}" ]] || die "APP_USER must be set"
    [[ -n "${PYTHON_ENV_FILE}" ]] || die "PYTHON_ENV_FILE must be set"
    [[ -n "${MINIO_ROOT_USER}" ]] || die "MINIO_ROOT_USER must be set"
    [[ -n "${MINIO_ROOT_PASSWORD}" ]] || die "MINIO_ROOT_PASSWORD must be set"
}

validate_keycloak() {
    [[ -n "${KEYCLOAK_DIR}" ]] || die "KEYCLOAK_DIR must be set"
    [[ -n "${KEYCLOAK_VERSION}" ]] || die "KEYCLOAK_VERSION must be set"
    [[ -n "${KEYCLOAK_ADMIN_USER}" ]] || die "KEYCLOAK_ADMIN_USER must be set"
    [[ -n "${KEYCLOAK_ADMIN_PASSWORD}" ]] || die "KEYCLOAK_ADMIN_PASSWORD must be set"
}

validate_common
case "${ROLE}" in
    frontend) validate_frontend ;;
    backend) validate_backend ;;
    keycloak) validate_keycloak ;;
    all)
        validate_frontend
        validate_backend
        validate_keycloak
        ;;
esac

log_success "Pre-deploy checks passed for role: ${ROLE}"

#!/usr/bin/env bash
# Verify the health of a deployed MXA Transcription role.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/post-deploy-validate.sh <frontend|backend|keycloak|all>
#
# Performs role-specific checks against services, ports, and HTTP health
# endpoints to confirm the deployment is operational.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

ROLE="${1:-}"
[[ -n "${ROLE}" ]] || die "Usage: $0 <frontend|backend|keycloak|all>"
case "${ROLE}" in frontend|backend|keycloak|all) ;; *) die "Invalid role: ${ROLE}" ;; esac

require_root
require_commands curl systemctl

validate_frontend() {
    service_active apache2 || die "apache2 is not active"
    service_active postgresql || die "postgresql is not active"
    run apache2ctl -t
    http_ok "http://127.0.0.1/" || die "Frontend HTTP check failed"
    [[ -f "${PHP_ENV_FILE}" ]] || die "Missing PHP env file: ${PHP_ENV_FILE}"
    log_success "Frontend validation passed"
}

validate_backend() {
    service_active redis-server || die "redis-server is not active"
    service_active minio || die "minio is not active"
    service_active mxa-api || die "mxa-api is not active"
    service_active mxa-celery || die "mxa-celery is not active"
    http_ok "http://127.0.0.1:${BACKEND_API_PORT}/health" || die "Backend health endpoint failed"
    [[ -f "${PYTHON_ENV_FILE}" ]] || die "Missing Python env file: ${PYTHON_ENV_FILE}"
    log_success "Backend validation passed"
}

validate_keycloak() {
    service_active keycloak || die "keycloak is not active"
    http_ok "http://127.0.0.1:${KEYCLOAK_HTTP_PORT}/" || die "Keycloak HTTP check failed"
    log_success "Keycloak validation passed"
}

case "${ROLE}" in
    frontend) validate_frontend ;;
    backend) validate_backend ;;
    keycloak) validate_keycloak ;;
    all)
        validate_keycloak
        validate_backend
        validate_frontend
        ;;
esac

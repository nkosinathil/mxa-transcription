#!/usr/bin/env bash
# Main orchestrator for MXA Transcription deployment.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/deploy-master.sh <frontend|backend|keycloak|all>
#
# The script runs pre-checks, role-specific layered setup scripts, and post-
# deployment validation. Typical production usage is one role per host.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROLE="${1:-}"
[[ -n "${ROLE}" ]] || { echo "Usage: $0 <frontend|backend|keycloak|all>" >&2; exit 1; }

"${SCRIPT_DIR}/pre-deploy-check.sh" "${ROLE}"

case "${ROLE}" in
    frontend)
        "${SCRIPT_DIR}/setup-app.sh" frontend
        "${SCRIPT_DIR}/setup-database.sh"
        "${SCRIPT_DIR}/setup-web.sh"
        ;;
    backend)
        "${SCRIPT_DIR}/setup-app.sh" backend
        "${SCRIPT_DIR}/setup-backend.sh"
        "${SCRIPT_DIR}/setup-storage.sh"
        "${SCRIPT_DIR}/setup-worker.sh"
        ;;
    keycloak)
        "${SCRIPT_DIR}/setup-keycloak.sh"
        ;;
    all)
        "${SCRIPT_DIR}/setup-keycloak.sh"
        "${SCRIPT_DIR}/setup-app.sh" backend
        "${SCRIPT_DIR}/setup-backend.sh"
        "${SCRIPT_DIR}/setup-storage.sh"
        "${SCRIPT_DIR}/setup-worker.sh"
        "${SCRIPT_DIR}/setup-app.sh" frontend
        "${SCRIPT_DIR}/setup-database.sh"
        "${SCRIPT_DIR}/setup-web.sh"
        ;;
    *)
        echo "Invalid role: ${ROLE}" >&2
        exit 1
        ;;
esac

"${SCRIPT_DIR}/post-deploy-validate.sh" "${ROLE}"

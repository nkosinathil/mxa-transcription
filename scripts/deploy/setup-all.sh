#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
    cat <<'EOF'
Usage: scripts/deploy/setup-all.sh <app|python|sso>

Runs the setup flow for one of the three server roles:
  app     - Apache/PHP/PostgreSQL app server
  python  - FastAPI/Celery/Redis/MinIO processing server
  sso     - Keycloak identity server
EOF
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

ROLE="$1"

case "${ROLE}" in
    app)
        exec "${SCRIPT_DIR}/setup-app-server.sh"
        ;;
    python)
        exec "${SCRIPT_DIR}/setup-python-server.sh"
        ;;
    sso)
        exec "${SCRIPT_DIR}/setup-sso-server.sh"
        ;;
    *)
        err "Unknown role: ${ROLE}"
        usage
        exit 1
        ;;
esac

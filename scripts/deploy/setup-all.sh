#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
    cat <<'EOF'
Usage: scripts/deploy/setup-all.sh [--non-interactive] <app|python|sso>

Runs the setup flow for one of the three server roles:
  app     - Apache/PHP/PostgreSQL app server
  python  - FastAPI/Celery/Redis/MinIO processing server
  sso     - Keycloak identity server

Options:
  --non-interactive   disable prompts (required values must be provided via env)
EOF
}

NON_INTERACTIVE_FLAG=""
if [[ $# -gt 0 && "$1" == "--non-interactive" ]]; then
    NON_INTERACTIVE_FLAG="--non-interactive"
    shift
fi

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

ROLE="$1"

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
        err "Unknown role: ${ROLE}"
        usage
        exit 1
        ;;
esac

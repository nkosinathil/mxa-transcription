#!/usr/bin/env bash
# Compatibility wrapper for the new deployment framework.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/php-server/deploy.sh

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/../scripts/deploy-master.sh" frontend "$@"

#!/usr/bin/env bash
# Install and configure PostgreSQL for the frontend role.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-database.sh
#
# Creates the application database and role when DB_LOCAL=true and imports the
# schema once if the expected core tables do not yet exist.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands apt-get systemctl runuser
[[ "${DB_USER}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "DB_USER contains unsupported characters"
[[ "${DB_NAME}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "DB_NAME contains unsupported characters"
[[ "${DB_PASSWORD}" != *"'"* ]] || die "DB_PASSWORD must not contain single quotes"
[[ "${DB_PASSWORD}" != *$'
'* ]] || die "DB_PASSWORD must not contain newlines"
[[ "${DB_PASSWORD}" != *$''* ]] || die "DB_PASSWORD must not contain carriage returns"

apt_install postgresql postgresql-client
require_commands psql
run systemctl enable postgresql
run systemctl restart postgresql

if [[ "${DB_LOCAL}" != "true" ]]; then
    log_warn "DB_LOCAL is not true; skipping local PostgreSQL provisioning"
    exit 0
fi

user_exists="$(runuser -u "${DB_SUPERUSER}" -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | tr -d '[:space:]' || true)"
db_exists="$(runuser -u "${DB_SUPERUSER}" -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | tr -d '[:space:]' || true)"

if [[ "${user_exists}" != "1" ]]; then
    run runuser -u "${DB_SUPERUSER}" -- psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
fi
if [[ "${db_exists}" != "1" ]]; then
    run runuser -u "${DB_SUPERUSER}" -- psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
fi
run runuser -u "${DB_SUPERUSER}" -- psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

schema_file="${FRONTEND_APP_DIR}/database/migrations/001_initial_schema.sql"
[[ -f "${schema_file}" ]] || die "Schema file not found: ${schema_file}"

jobs_table_exists="$(runuser -u "${DB_SUPERUSER}" -- psql -d "${DB_NAME}" -tAc "SELECT to_regclass('public.jobs') IS NOT NULL" | tr -d '[:space:]')"
if [[ "${jobs_table_exists}" == "t" ]]; then
    log_info "Database schema already present; skipping schema import"
else
    run runuser -u "${DB_SUPERUSER}" -- psql -d "${DB_NAME}" -f "${schema_file}"
fi

log_success "Database setup complete"

#!/usr/bin/env bash
# Roll back a frontend or backend deployment to the previous recorded git revision.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/rollback.sh <frontend|backend>
#
# This rollback restores the previous application revision and selected config
# backups, then restarts the associated services. It does not revert database or
# object-storage data.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

ROLE="${1:-}"
case "${ROLE}" in frontend|backend) ;; *) die "Usage: $0 <frontend|backend>" ;; esac

require_root
require_commands git systemctl

app_dir="$(role_to_app_dir "${ROLE}")"
state_dir="$(state_dir_for_role "${ROLE}")"
previous_revision_file="${state_dir}/previous_revision"
[[ -f "${previous_revision_file}" ]] || die "No previous revision recorded for role: ${ROLE}"
previous_revision="$(tr -d '[:space:]' < "${previous_revision_file}")"
[[ -n "${previous_revision}" ]] || die "Previous revision file is empty"
[[ -d "${app_dir}/.git" ]] || die "App directory is not a git checkout: ${app_dir}"

run git -C "${app_dir}" reset --hard "${previous_revision}"

if [[ "${ROLE}" == "backend" ]]; then
    restore_file_from_backup backend /etc/systemd/system/minio.service
    restore_file_from_backup backend /etc/systemd/system/mxa-api.service
    restore_file_from_backup backend /etc/systemd/system/mxa-celery.service
    run sudo -u "${APP_USER}" "${BACKEND_VENV_DIR}/bin/pip" install -r "${BACKEND_APP_DIR}/python-backend/requirements.txt"
    run systemctl daemon-reload
    run systemctl restart minio
    run systemctl restart mxa-api
    run systemctl restart mxa-celery
else
    restore_file_from_backup frontend "/etc/apache2/sites-available/${APACHE_SITE_NAME}.conf"
    run apache2ctl -t
    run systemctl restart apache2
fi

log_success "Rollback complete for role: ${ROLE}"

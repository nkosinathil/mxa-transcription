#!/usr/bin/env bash
# Install and configure Apache and PHP for the frontend role.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-web.sh
#
# Installs PHP/Apache packages, renders the Apache virtual host, writes the PHP
# runtime env file from deployment variables, and applies filesystem permissions.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands apt-get systemctl

apt_install ${PHP_PACKAGES}
require_commands apache2ctl a2enmod a2ensite a2dissite
ensure_dir "${FRONTEND_APP_DIR}/php-app/storage/logs"
ensure_dir "${FRONTEND_APP_DIR}/php-app/storage/uploads"
write_php_runtime_env

backup_file frontend "/etc/apache2/sites-available/${APACHE_SITE_NAME}.conf"
render_template "${DEPLOY_ROOT}/apache/mxa-transcription.conf.template" "/etc/apache2/sites-available/${APACHE_SITE_NAME}.conf" \
    FRONTEND_SERVER_NAME "${FRONTEND_SERVER_NAME}" \
    FRONTEND_APP_DIR "${FRONTEND_APP_DIR}" \
    APACHE_LOG_DIR "${APACHE_LOG_DIR}"

chown -R root:"${WEB_GROUP}" "${FRONTEND_APP_DIR}"
chmod -R 0755 "${FRONTEND_APP_DIR}"
chown -R "${WEB_USER}:${WEB_GROUP}" "${FRONTEND_APP_DIR}/php-app/storage"
chmod -R 0775 "${FRONTEND_APP_DIR}/php-app/storage"
chmod 0640 "${PHP_ENV_FILE}"
chown root:"${WEB_GROUP}" "${PHP_ENV_FILE}"

run a2enmod rewrite
run a2enmod headers
run a2ensite "${APACHE_SITE_NAME}.conf"
run a2dissite 000-default.conf || true
run apache2ctl -t
run systemctl enable apache2
run systemctl restart apache2

log_success "Apache and PHP configured"

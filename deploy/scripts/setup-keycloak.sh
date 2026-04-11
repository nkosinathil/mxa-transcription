#!/usr/bin/env bash
# Install and configure Keycloak on the identity host.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-keycloak.sh
#
# Downloads the configured Keycloak release, provisions the service user,
# bootstraps the admin account once, installs the systemd unit, and starts the
# Keycloak service.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands apt-get systemctl

apt_install ${KEYCLOAK_PACKAGES}
require_commands wget unzip
ensure_user "${KEYCLOAK_USER}" "/usr/sbin/nologin"
backup_file keycloak /etc/systemd/system/keycloak.service

keycloak_zip="/tmp/keycloak-${KEYCLOAK_VERSION}.zip"
keycloak_url="https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.zip"

if [[ ! -x "${KEYCLOAK_DIR}/bin/kc.sh" ]]; then
    wget -q "${keycloak_url}" -O "${keycloak_zip}"
    rm -rf "${KEYCLOAK_DIR}" "${KEYCLOAK_DIR}.tmp"
    unzip -q "${keycloak_zip}" -d /opt
    mv "/opt/keycloak-${KEYCLOAK_VERSION}" "${KEYCLOAK_DIR}"
    rm -f "${keycloak_zip}"
fi

chown -R "${KEYCLOAK_USER}:${KEYCLOAK_GROUP}" "${KEYCLOAK_DIR}"
write_env_kv_file "${KEYCLOAK_ENV_FILE}" \
    KC_BOOTSTRAP_ADMIN_USERNAME "${KEYCLOAK_ADMIN_USER}" \
    KC_BOOTSTRAP_ADMIN_PASSWORD "${KEYCLOAK_ADMIN_PASSWORD}" \
    KC_HOSTNAME "${KEYCLOAK_HOSTNAME}" \
    KC_HTTP_PORT "${KEYCLOAK_HTTP_PORT}" \
    KC_PROXY "edge"
chmod 0600 "${KEYCLOAK_ENV_FILE}"

if [[ ! -f "${KEYCLOAK_DIR}/.admin_bootstrapped" ]]; then
    log_info "Bootstrapping Keycloak admin user"
    sudo -u "${KEYCLOAK_USER}" bash -lc "set -a && source '${KEYCLOAK_ENV_FILE}' && set +a && '${KEYCLOAK_DIR}/bin/kc.sh' bootstrap-admin"
    touch "${KEYCLOAK_DIR}/.admin_bootstrapped"
    chown "${KEYCLOAK_USER}:${KEYCLOAK_GROUP}" "${KEYCLOAK_DIR}/.admin_bootstrapped"
fi

render_template "${DEPLOY_ROOT}/systemd/keycloak.service.template" /etc/systemd/system/keycloak.service \
    KEYCLOAK_USER "${KEYCLOAK_USER}" \
    KEYCLOAK_GROUP "${KEYCLOAK_GROUP}" \
    KEYCLOAK_DIR "${KEYCLOAK_DIR}" \
    KEYCLOAK_ENV_FILE "${KEYCLOAK_ENV_FILE}"
restart_service keycloak

log_success "Keycloak configured"

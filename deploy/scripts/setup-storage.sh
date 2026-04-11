#!/usr/bin/env bash
# Install and configure MinIO object storage for the backend host.
# Usage:
#   sudo DEPLOY_ENV_FILE=/absolute/path/to/deploy.env ./deploy/scripts/setup-storage.sh
#
# Downloads the MinIO binary with SHA256 verification, writes the MinIO env file,
# installs the systemd unit, and starts the service.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
load_deploy_env

require_root
require_commands wget sha256sum systemctl

local_binary="/usr/local/bin/minio"
tmp_binary="$(mktemp)"
tmp_sha="$(mktemp)"

wget -q "${MINIO_BINARY_URL}" -O "${tmp_binary}"
wget -q "${MINIO_SHA256_URL}" -O "${tmp_sha}"
expected_sha="$(awk '{print $1}' "${tmp_sha}")"
actual_sha="$(sha256sum "${tmp_binary}" | awk '{print $1}')"
[[ "${expected_sha}" == "${actual_sha}" ]] || die "MinIO checksum verification failed"

install -m 0755 "${tmp_binary}" "${local_binary}"
rm -f "${tmp_binary}" "${tmp_sha}"

ensure_dir "${MINIO_DATA_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "$(dirname "${MINIO_DATA_DIR}")"
write_env_kv_file "${MINIO_ENV_FILE}" \
    MINIO_ROOT_USER "${MINIO_ROOT_USER}" \
    MINIO_ROOT_PASSWORD "${MINIO_ROOT_PASSWORD}" \
    MINIO_DATA_DIR "${MINIO_DATA_DIR}" \
    MINIO_CONSOLE_ADDRESS "${MINIO_CONSOLE_ADDRESS}"
chmod 0600 "${MINIO_ENV_FILE}"

backup_file backend /etc/systemd/system/minio.service
render_template "${DEPLOY_ROOT}/systemd/minio.service.template" /etc/systemd/system/minio.service \
    APP_USER "${APP_USER}" \
    APP_GROUP "${APP_GROUP}" \
    MINIO_ENV_FILE "${MINIO_ENV_FILE}"
restart_service minio

log_success "MinIO configured"

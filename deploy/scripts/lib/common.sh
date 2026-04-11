#!/usr/bin/env bash
# Shared deployment helpers for MXA Transcription.
# Usage:
#   source "$(dirname "$0")/lib/common.sh"
#   load_deploy_env
#   log_info "message"
#
# All deploy scripts source this file for environment loading, logging,
# template rendering, runtime env generation, backups, git checkout, and safe
# command wrappers.

set -Eeuo pipefail

DEPLOY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPTS_DIR="$(cd "${DEPLOY_LIB_DIR}/.." && pwd)"
DEPLOY_ROOT="$(cd "${DEPLOY_SCRIPTS_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DEPLOY_ROOT}/.." && pwd)"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-${DEPLOY_ROOT}/env/deploy.env}"

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

load_deploy_env() {
    if [[ -f "${DEPLOY_ENV_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${DEPLOY_ENV_FILE}"
    fi

    APP_NAME="${APP_NAME:-MXA Transcription}"
    APP_DEBUG="${APP_DEBUG:-false}"
    REPO_URL="${REPO_URL:-https://github.com/nkosinathil/mxa-transcription.git}"
    DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
    GIT_REMOTE_NAME="${GIT_REMOTE_NAME:-origin}"

    FRONTEND_APP_DIR="${FRONTEND_APP_DIR:-/var/www/html/mxa-transcription}"
    FRONTEND_SERVER_NAME="${FRONTEND_SERVER_NAME:-192.168.1.66}"
    WEB_USER="${WEB_USER:-www-data}"
    WEB_GROUP="${WEB_GROUP:-www-data}"
    APACHE_SITE_NAME="${APACHE_SITE_NAME:-mxa-transcription}"
    APACHE_LOG_DIR="${APACHE_LOG_DIR:-/var/log/apache2}"

    BACKEND_APP_DIR="${BACKEND_APP_DIR:-/opt/mxa-transcription}"
    BACKEND_HOST="${BACKEND_HOST:-192.168.1.90}"
    BACKEND_API_HOST="${BACKEND_API_HOST:-0.0.0.0}"
    BACKEND_API_PORT="${BACKEND_API_PORT:-8000}"
    APP_USER="${APP_USER:-mxa}"
    APP_GROUP="${APP_GROUP:-${APP_USER}}"
    PYTHON_BIN="${PYTHON_BIN:-python3}"
    BACKEND_VENV_DIR="${BACKEND_VENV_DIR:-${BACKEND_APP_DIR}/venv}"
    BACKEND_LOG_DIR="${BACKEND_LOG_DIR:-/var/log/mxa-transcription}"
    CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-2}"

    DB_LOCAL="${DB_LOCAL:-true}"
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-mxa_transcription}"
    DB_USER="${DB_USER:-mxa_transcription}"
    DB_PASSWORD="${DB_PASSWORD:-change_this_password}"
    DB_SUPERUSER="${DB_SUPERUSER:-postgres}"
    DATABASE_URL="${DATABASE_URL:-postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}}"

    REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
    CELERY_BROKER_URL="${CELERY_BROKER_URL:-redis://localhost:6379/0}"
    CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-redis://localhost:6379/1}"

    API_SECRET_KEY="${API_SECRET_KEY:-change-this-in-production}"
    PHP_ENV_FILE="${PHP_ENV_FILE:-${FRONTEND_APP_DIR}/php-app/.env}"
    PYTHON_ENV_FILE="${PYTHON_ENV_FILE:-${BACKEND_APP_DIR}/python-backend/.env}"
    PHP_APP_URL="${PHP_APP_URL:-http://${FRONTEND_SERVER_NAME}}"
    PHP_API_BASE_URL="${PHP_API_BASE_URL:-http://${BACKEND_HOST}:${BACKEND_API_PORT}/api/v1}"
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-${PHP_APP_URL},http://localhost}"
    KEYCLOAK_SERVER_URL="${KEYCLOAK_SERVER_URL:-http://192.168.1.59:8080}"
    KEYCLOAK_REALM="${KEYCLOAK_REALM:-mxa-transcription}"
    KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID:-mxa-transcription-client}"
    KEYCLOAK_CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET:-your_keycloak_client_secret_here}"
    KEYCLOAK_REDIRECT_URI="${KEYCLOAK_REDIRECT_URI:-${PHP_APP_URL}/auth/callback}"
    LOG_LEVEL="${LOG_LEVEL:-info}"
    WHISPER_MODEL_SIZE="${WHISPER_MODEL_SIZE:-base}"
    WHISPER_DEVICE="${WHISPER_DEVICE:-auto}"
    WHISPER_COMPUTE_TYPE="${WHISPER_COMPUTE_TYPE:-int8}"
    DIARIZATION_ENABLED="${DIARIZATION_ENABLED:-True}"
    HUGGINGFACE_TOKEN="${HUGGINGFACE_TOKEN:-}"
    MAX_UPLOAD_SIZE="${MAX_UPLOAD_SIZE:-524288000}"

    MINIO_BINARY_URL="${MINIO_BINARY_URL:-https://dl.min.io/server/minio/release/linux-amd64/minio}"
    MINIO_SHA256_URL="${MINIO_SHA256_URL:-${MINIO_BINARY_URL}.sha256sum}"
    MINIO_DATA_DIR="${MINIO_DATA_DIR:-/opt/minio/data}"
    MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost:9000}"
    MINIO_SECURE="${MINIO_SECURE:-False}"
    MINIO_CONSOLE_ADDRESS="${MINIO_CONSOLE_ADDRESS:-:9001}"
    MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
    MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
    MINIO_ENV_FILE="${MINIO_ENV_FILE:-/etc/mxa-transcription/minio.env}"

    KEYCLOAK_VERSION="${KEYCLOAK_VERSION:-21.1.2}"
    KEYCLOAK_USER="${KEYCLOAK_USER:-keycloak}"
    KEYCLOAK_GROUP="${KEYCLOAK_GROUP:-${KEYCLOAK_USER}}"
    KEYCLOAK_DIR="${KEYCLOAK_DIR:-/opt/keycloak}"
    KEYCLOAK_HOSTNAME="${KEYCLOAK_HOSTNAME:-192.168.1.59}"
    KEYCLOAK_HTTP_PORT="${KEYCLOAK_HTTP_PORT:-8080}"
    KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
    KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-change-this-immediately}"
    KEYCLOAK_ENV_FILE="${KEYCLOAK_ENV_FILE:-/etc/mxa-transcription/keycloak.env}"

    PHP_PACKAGES="${PHP_PACKAGES:-apache2 php php-cli php-common php-curl php-mbstring php-pgsql php-xml libapache2-mod-php postgresql postgresql-client git curl unzip ca-certificates}"
    BACKEND_PACKAGES="${BACKEND_PACKAGES:-python3 python3-venv python3-pip redis-server git curl wget ffmpeg build-essential libpq-dev libsndfile1 ca-certificates}"
    KEYCLOAK_PACKAGES="${KEYCLOAK_PACKAGES:-openjdk-17-jre-headless curl unzip wget ca-certificates}"
}

log_info() { printf '%b[INFO]%b %s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$*"; }
log_warn() { printf '%b[WARN]%b %s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"; }
log_success() { printf '%b[ OK ]%b %s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$*"; }
log_error() { printf '%b[ERR ]%b %s\n' "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2; }

die() {
    log_error "$*"
    exit 1
}

run() {
    log_info "$*"
    "$@"
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "This script must be run as root or via sudo."
    fi
}

require_commands() {
    local cmd
    for cmd in "$@"; do
        command -v "${cmd}" >/dev/null 2>&1 || die "Required command not found: ${cmd}"
    done
}

ensure_dir() {
    local target="$1"
    install -d -m 0755 "${target}"
}

ensure_user() {
    local user="$1"
    local shell="${2:-/bin/bash}"
    if id "${user}" >/dev/null 2>&1; then
        log_info "User ${user} already exists"
    else
        run useradd -m -s "${shell}" "${user}"
    fi
}

apt_install() {
    export DEBIAN_FRONTEND=noninteractive
    run apt-get update
    run apt-get install -y "$@"
}

role_to_app_dir() {
    case "$1" in
        frontend) printf '%s\n' "${FRONTEND_APP_DIR}" ;;
        backend) printf '%s\n' "${BACKEND_APP_DIR}" ;;
        keycloak) printf '%s\n' "${KEYCLOAK_DIR}" ;;
        *) die "Unknown role for app dir: $1" ;;
    esac
}

state_dir_for_role() {
    local role="$1"
    local app_dir
    app_dir="$(role_to_app_dir "${role}")"
    printf '%s\n' "${app_dir}/.deploy-state"
}

record_previous_revision() {
    local role="$1"
    local app_dir state_dir current_rev
    app_dir="$(role_to_app_dir "${role}")"
    state_dir="$(state_dir_for_role "${role}")"
    ensure_dir "${state_dir}"

    if [[ -d "${app_dir}/.git" ]]; then
        current_rev="$(git -C "${app_dir}" rev-parse HEAD 2>/dev/null || true)"
        if [[ -n "${current_rev}" ]]; then
            printf '%s\n' "${current_rev}" > "${state_dir}/previous_revision"
        fi
    fi
}

record_current_revision() {
    local role="$1"
    local app_dir state_dir current_rev
    app_dir="$(role_to_app_dir "${role}")"
    state_dir="$(state_dir_for_role "${role}")"
    ensure_dir "${state_dir}"
    current_rev="$(git -C "${app_dir}" rev-parse HEAD)"
    printf '%s\n' "${current_rev}" > "${state_dir}/current_revision"
}

backup_file() {
    local role="$1"
    local source_file="$2"
    local state_dir backup_root rel_path
    [[ -e "${source_file}" ]] || return 0

    state_dir="$(state_dir_for_role "${role}")"
    backup_root="${state_dir}/backups/latest"
    rel_path="${source_file#/}"
    ensure_dir "$(dirname "${backup_root}/${rel_path}")"
    cp -a "${source_file}" "${backup_root}/${rel_path}"
}

restore_file_from_backup() {
    local role="$1"
    local target_file="$2"
    local state_dir backup_root rel_path backup_file_path
    state_dir="$(state_dir_for_role "${role}")"
    backup_root="${state_dir}/backups/latest"
    rel_path="${target_file#/}"
    backup_file_path="${backup_root}/${rel_path}"
    [[ -e "${backup_file_path}" ]] || return 0
    ensure_dir "$(dirname "${target_file}")"
    cp -a "${backup_file_path}" "${target_file}"
}

clone_or_update_repo() {
    local role="$1"
    local app_dir
    app_dir="$(role_to_app_dir "${role}")"

    ensure_dir "$(dirname "${app_dir}")"
    record_previous_revision "${role}"

    if [[ -d "${app_dir}/.git" ]]; then
        run git -C "${app_dir}" fetch "${GIT_REMOTE_NAME}" "${DEPLOY_BRANCH}"
        run git -C "${app_dir}" checkout -f "${DEPLOY_BRANCH}"
        run git -C "${app_dir}" reset --hard "${GIT_REMOTE_NAME}/${DEPLOY_BRANCH}"
    elif [[ -d "${app_dir}" ]] && [[ -n "$(ls -A "${app_dir}" 2>/dev/null || true)" ]]; then
        die "Target directory ${app_dir} exists but is not a git checkout."
    else
        run git clone --branch "${DEPLOY_BRANCH}" "${REPO_URL}" "${app_dir}"
    fi

    record_current_revision "${role}"
}

bootstrap_env_file() {
    local target="$1"
    local example_file="$2"
    if [[ -f "${target}" ]]; then
        log_info "Keeping existing env file: ${target}"
    else
        ensure_dir "$(dirname "${target}")"
        run cp "${example_file}" "${target}"
        log_warn "Created ${target}; populate secrets before production use."
    fi
}

write_env_kv_file() {
    local target="$1"
    shift
    ensure_dir "$(dirname "${target}")"
    : > "${target}"

    while (($#)); do
        local key="$1"
        local value="$2"
        shift 2
        value="${value//\\/\\\\}"
        value="${value//\"/\\\"}"
        printf '%s="%s"\n' "${key}" "${value}" >> "${target}"
    done
}

write_php_runtime_env() {
    backup_file frontend "${PHP_ENV_FILE}"
    write_env_kv_file "${PHP_ENV_FILE}" \
        APP_NAME "${APP_NAME}" \
        APP_URL "${PHP_APP_URL}" \
        APP_DEBUG "${APP_DEBUG}" \
        DB_HOST "${DB_HOST}" \
        DB_PORT "${DB_PORT}" \
        DB_NAME "${DB_NAME}" \
        DB_USER "${DB_USER}" \
        DB_PASSWORD "${DB_PASSWORD}" \
        API_BASE_URL "${PHP_API_BASE_URL}" \
        API_SECRET_KEY "${API_SECRET_KEY}" \
        KEYCLOAK_SERVER_URL "${KEYCLOAK_SERVER_URL}" \
        KEYCLOAK_REALM "${KEYCLOAK_REALM}" \
        KEYCLOAK_CLIENT_ID "${KEYCLOAK_CLIENT_ID}" \
        KEYCLOAK_CLIENT_SECRET "${KEYCLOAK_CLIENT_SECRET}" \
        KEYCLOAK_REDIRECT_URI "${KEYCLOAK_REDIRECT_URI}" \
        LOG_LEVEL "${LOG_LEVEL}"
}

write_python_runtime_env() {
    backup_file backend "${PYTHON_ENV_FILE}"
    write_env_kv_file "${PYTHON_ENV_FILE}" \
        API_SECRET_KEY "${API_SECRET_KEY}" \
        DEBUG "${APP_DEBUG}" \
        ALLOWED_ORIGINS "${ALLOWED_ORIGINS}" \
        DATABASE_URL "${DATABASE_URL}" \
        REDIS_URL "${REDIS_URL}" \
        CELERY_BROKER_URL "${CELERY_BROKER_URL}" \
        CELERY_RESULT_BACKEND "${CELERY_RESULT_BACKEND}" \
        MINIO_ENDPOINT "${MINIO_ENDPOINT}" \
        MINIO_ACCESS_KEY "${MINIO_ROOT_USER}" \
        MINIO_SECRET_KEY "${MINIO_ROOT_PASSWORD}" \
        MINIO_SECURE "${MINIO_SECURE}" \
        WHISPER_MODEL_SIZE "${WHISPER_MODEL_SIZE}" \
        WHISPER_DEVICE "${WHISPER_DEVICE}" \
        WHISPER_COMPUTE_TYPE "${WHISPER_COMPUTE_TYPE}" \
        DIARIZATION_ENABLED "${DIARIZATION_ENABLED}" \
        HUGGINGFACE_TOKEN "${HUGGINGFACE_TOKEN}" \
        MAX_UPLOAD_SIZE "${MAX_UPLOAD_SIZE}"
}

render_template() {
    local template_file="$1"
    local output_file="$2"
    shift 2

    local tmp_file
    tmp_file="$(mktemp)"
    cp "${template_file}" "${tmp_file}"

    while (($#)); do
        local token="$1"
        local value="$2"
        shift 2
        value="$(printf '%s' "${value}" | sed -e 's/[\\/&|]/\\&/g')"
        sed -i "s|{{${token}}}|${value}|g" "${tmp_file}"
    done

    ensure_dir "$(dirname "${output_file}")"
    mv "${tmp_file}" "${output_file}"
}

restart_service() {
    local service_name="$1"
    run systemctl daemon-reload
    run systemctl enable "${service_name}"
    run systemctl restart "${service_name}"
}

service_active() {
    systemctl is-active --quiet "$1"
}

http_ok() {
    local url="$1"
    curl --silent --show-error --fail --location --max-time 10 "$url" >/dev/null
}

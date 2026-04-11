#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo -e "\n${BLUE}================================================================${NC}"
  echo -e "${BLUE}$*${NC}"
  echo -e "${BLUE}================================================================${NC}\n"
}

print_step() {
  echo -e "${BLUE}==> $*${NC}"
}

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

err() {
  echo -e "${RED}[ERROR]${NC} $*"
}

print_warn() {
  warn "$@"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "This script must run as root (use sudo)."
    exit 1
  fi
}

ensure_root() {
  require_root
}

require_command() {
  local cmd="${1}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    err "Required command not found: ${cmd}"
    exit 1
  fi
}

run_cmd() {
  "$@"
}

prompt_default() {
  local message="${1}"
  local default_value="${2}"
  local response
  read -r -p "${message} [${default_value}]: " response
  if [[ -z "${response}" ]]; then
    response="${default_value}"
  fi
  printf '%s' "${response}"
}

prompt_required() {
  local message="${1}"
  local response=""
  while [[ -z "${response}" ]]; do
    read -r -p "${message}: " response
  done
  printf '%s' "${response}"
}

prompt_secret() {
  local var_name="${1}"
  local message="${2}"
  local response
  read -r -s -p "${message}: " response
  echo ""
  printf -v "${var_name}" '%s' "${response}"
}

prompt_secret_confirm() {
  local message="${1}"
  local first
  local second
  while true; do
    read -r -s -p "${message}: " first
    echo ""
    read -r -s -p "Confirm ${message}: " second
    echo ""
    if [[ "${first}" == "${second}" ]]; then
      printf '%s' "${first}"
      return
    fi
    warn "Values did not match. Please retry."
  done
}

prompt_value() {
  local var_name="${1}"
  local message="${2}"
  local default_value="${3}"
  local response
  read -r -p "${message} [${default_value}]: " response
  if [[ -z "${response}" ]]; then
    response="${default_value}"
  fi
  printf -v "${var_name}" '%s' "${response}"
}

write_env_value() {
  local env_file="${1}"
  local key="${2}"
  local value="${3}"
  local escaped
  escaped=$(printf '%s' "${value}" | sed 's/[\/&]/\\&/g')

  if rg -q "^${key}=" "${env_file}"; then
    sed -i "s|^${key}=.*|${key}=${escaped}|" "${env_file}"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> "${env_file}"
  fi
}

set_env_var() {
  write_env_value "$@"
}

random_hex_32() {
  python3 -c "import secrets; print(secrets.token_hex(32))"
}

generate_secret() {
  random_hex_32
}

bool_from_url() {
  local url="${1}"
  if [[ "${url,,}" == https://* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

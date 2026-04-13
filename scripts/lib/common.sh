#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

is_non_interactive() {
  local mode="${NON_INTERACTIVE:-0}"
  [[ "${mode}" == "1" || "${mode,,}" == "true" || ! -t 0 ]]
}

parse_non_interactive_flag() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive)
        export NON_INTERACTIVE=true
        ;;
    esac
    shift
  done
}

parse_non_interactive_flags() {
  parse_non_interactive_flag "$@"
}

parse_common_flags() {
  parse_non_interactive_flag "$@"
}

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
  if is_non_interactive; then
    printf '%s' "${default_value}"
    return
  fi
  read -r -p "${message} [${default_value}]: " response
  if [[ -z "${response}" ]]; then
    response="${default_value}"
  fi
  printf '%s' "${response}"
}

prompt_required() {
  local message="${1}"
  local response=""
  if is_non_interactive; then
    err "Missing required value for: ${message}. Provide it via environment variables in non-interactive mode."
    exit 1
  fi
  while [[ -z "${response}" ]]; do
    read -r -p "${message}: " response
  done
  printf '%s' "${response}"
}

prompt_secret() {
  local var_name="${1}"
  local message="${2}"
  local response
  if [[ -n "${!var_name:-}" ]]; then
    return
  fi
  if is_non_interactive; then
    err "Missing required secret: ${var_name}. Set it as an environment variable in non-interactive mode."
    exit 1
  fi
  read -r -s -p "${message}: " response
  echo ""
  printf -v "${var_name}" '%s' "${response}"
}

prompt_secret_confirm() {
  local message="${1}"
  local first
  local second
  if is_non_interactive; then
    err "Cannot prompt for ${message} in non-interactive mode."
    exit 1
  fi
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
  if [[ -n "${!var_name:-}" ]]; then
    return
  fi
  if is_non_interactive; then
    if [[ -z "${default_value}" ]]; then
      err "Missing required value: ${var_name}. Set it as an environment variable in non-interactive mode."
      exit 1
    fi
    printf -v "${var_name}" '%s' "${default_value}"
    return
  fi
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

  if grep -q "^${key}=" "${env_file}"; then
    sed -i "s|^${key}=.*|${key}=${escaped}|" "${env_file}"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> "${env_file}"
  fi
}

read_env_value() {
  local env_file="${1}"
  local key="${2}"
  local line
  line=$(grep "^${key}=" "${env_file}" 2>/dev/null | head -n 1 || true)
  if [[ -z "${line}" ]]; then
    return 1
  fi
  printf '%s' "${line#*=}"
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

validate_required_env_vars() {
  local key value
  for key in "$@"; do
    value="${!key:-}"
    if [[ -z "${value}" ]]; then
      if is_non_interactive; then
        err "Missing required env var: ${key}"
        exit 1
      fi
      read -r -p "Enter ${key}: " value
      while [[ -z "${value}" ]]; do
        read -r -p "Enter ${key}: " value
      done
      export "${key}=${value}"
    fi
  done
}

require_env_vars() {
  validate_required_env_vars "$@"
}

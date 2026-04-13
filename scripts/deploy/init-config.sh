#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_TEMPLATE="${SCRIPT_DIR}/env.example"
OUTPUT_PATH="${SCRIPT_DIR}/.env"

usage() {
  cat <<'EOF'
Usage: scripts/deploy/init-config.sh [--output <path>]

Creates a deployment config from env.example and auto-generates secure values
for all sensitive keys/passwords if they are missing or placeholders.

Examples:
  ./scripts/deploy/init-config.sh
  ./scripts/deploy/init-config.sh --output ./scripts/deploy/.env
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${SOURCE_TEMPLATE}" ]]; then
  echo "Template not found: ${SOURCE_TEMPLATE}" >&2
  exit 1
fi

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  cp "${SOURCE_TEMPLATE}" "${OUTPUT_PATH}"
fi

python3 - "${OUTPUT_PATH}" <<'PY'
from pathlib import Path
import re
import secrets
import sys

config_path = Path(sys.argv[1])
content = config_path.read_text(encoding="utf-8")

def random_hex(length: int = 64) -> str:
    return secrets.token_hex(length // 2)

def random_id(prefix: str, hex_len: int = 16) -> str:
    return f"{prefix}{secrets.token_hex(hex_len // 2)}"

def get_value(key: str):
    pattern = re.compile(rf'^\s*export\s+{re.escape(key)}="([^"]*)"\s*$', re.MULTILINE)
    match = pattern.search(content)
    if not match:
        return None
    return match.group(1)

def set_value(key: str, value: str):
    global content
    pattern = re.compile(rf'^\s*export\s+{re.escape(key)}="[^"]*"\s*$', re.MULTILINE)
    replacement = f'export {key}="{value}"'
    if pattern.search(content):
        content = pattern.sub(replacement, content, count=1)
    else:
        if not content.endswith("\n"):
            content += "\n"
        content += replacement + "\n"

def is_placeholder(value: str | None) -> bool:
    if value is None:
        return True
    value = value.strip()
    if value == "":
        return True
    markers = ("replace-with", "<", "changeme", "change-me")
    return any(marker in value.lower() for marker in markers)

secrets_map = {
    "SHARED_API_KEY": random_hex(64),
    "DB_PASS": random_hex(48),
    "MINIO_ACCESS_KEY": random_id("minio-", 16),
    "MINIO_SECRET_KEY": random_hex(64),
    "KEYCLOAK_CLIENT_SECRET": random_hex(64),
    "KC_ADMIN_PASS": random_hex(48),
    "KC_DB_PASS": random_hex(48),
}

for key, generated in secrets_map.items():
    if is_placeholder(get_value(key)):
        set_value(key, generated)

config_path.write_text(content, encoding="utf-8")
PY

chmod 600 "${OUTPUT_PATH}" || true

cat <<EOF
Config ready: ${OUTPUT_PATH}
Generated/ensured:
  - SHARED_API_KEY
  - DB_PASS
  - MINIO_ACCESS_KEY
  - MINIO_SECRET_KEY
  - KEYCLOAK_CLIENT_SECRET
  - KC_ADMIN_PASS
  - KC_DB_PASS

Next:
  1) Review/edit non-secret values (IPs, APP_URL) in ${OUTPUT_PATH}
  2) Copy this SAME file to each server
  3) Run:
     sudo ./scripts/deploy/deploy.sh --role sso --config ${OUTPUT_PATH}
     sudo ./scripts/deploy/deploy.sh --role python --config ${OUTPUT_PATH}
     sudo ./scripts/deploy/deploy.sh --role app --config ${OUTPUT_PATH}
EOF

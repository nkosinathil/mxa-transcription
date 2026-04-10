#!/usr/bin/env bash
# setup.sh — One-shot helper that copies .env templates and reminds the
# operator to fill in secrets before the first deployment.
#
# Run from the repository root:
#   bash setup.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

echo "============================================"
echo "  MXA Transcription — Initial Setup Helper"
echo "============================================"
echo

# ── PHP .env ────────────────────────────────────────────────────────────────
if [ -f php-app/.env ]; then
    echo "  [SKIP] php-app/.env already exists"
else
    cp php-app/.env.example php-app/.env
    echo "  [OK]   Created php-app/.env from template"
fi

# ── Python backend .env ─────────────────────────────────────────────────────
if [ -f python-backend/.env ]; then
    echo "  [SKIP] python-backend/.env already exists"
else
    cp python-backend/.env.example python-backend/.env
    echo "  [OK]   Created python-backend/.env from template"
fi

# ── Storage directories ─────────────────────────────────────────────────────
mkdir -p php-app/storage/logs php-app/storage/uploads
echo "  [OK]   Storage directories are present"

echo
echo "--------------------------------------------"
echo "  Action required: edit the .env files"
echo "--------------------------------------------"
echo
echo "  1. php-app/.env"
echo "     • DB_PASSWORD"
echo "     • API_SECRET_KEY           (shared with python-backend)"
echo "     • KEYCLOAK_CLIENT_SECRET   (from Keycloak Admin Console)"
echo
echo "  2. python-backend/.env"
echo "     • API_SECRET_KEY           (must match php-app)"
echo "     • MINIO_ACCESS_KEY / MINIO_SECRET_KEY"
echo "     • HUGGINGFACE_TOKEN        (for speaker diarization)"
echo
echo "  After editing, run:"
echo "    python3 validate-deployment.py --role all"
echo

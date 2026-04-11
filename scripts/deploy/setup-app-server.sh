#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

ensure_root
print_header "MXA Transcription - App Server Setup"

APP_DIR="${APP_DIR:-/opt/mxa-transcription}"
REPO_DIR="${REPO_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PHP_APP_DIR="$APP_DIR/php-app"

DB_NAME="${DB_NAME:-transcription_db}"
DB_USER="${DB_USER:-transcription_user}"
DB_PASS="${DB_PASS:-}"
KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-http://192.168.1.59:8080}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-mxa}"
KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID:-transcription-web}"
KEYCLOAK_CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET:-}"
APP_URL="${APP_URL:-http://192.168.1.66}"
PYTHON_API_BASE_URL="${PYTHON_API_BASE_URL:-http://192.168.1.90:8000}"
PYTHON_API_KEY="${PYTHON_API_KEY:-}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-192.168.1.90:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"

if [[ -z "$DB_PASS" || -z "$KEYCLOAK_CLIENT_SECRET" || -z "$PYTHON_API_KEY" || -z "$MINIO_ACCESS_KEY" || -z "$MINIO_SECRET_KEY" ]]; then
  echo "Required env vars missing. Set: DB_PASS, KEYCLOAK_CLIENT_SECRET, PYTHON_API_KEY, MINIO_ACCESS_KEY, MINIO_SECRET_KEY"
  exit 1
fi

print_step "Installing system packages"
apt-get update
apt-get install -y apache2 php php-fpm php-pgsql php-curl php-json php-mbstring php-xml composer postgresql postgresql-contrib

print_step "Creating app directory and syncing code"
mkdir -p "$APP_DIR"
rsync -a --delete "$REPO_DIR/php-app/" "$PHP_APP_DIR/"
rsync -a "$REPO_DIR/database/" "$APP_DIR/database/"
chown -R www-data:www-data "$PHP_APP_DIR/storage"

print_step "Configuring PostgreSQL"
systemctl enable --now postgresql
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true
export PGPASSWORD="$DB_PASS"
psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$APP_DIR/database/schema.sql"
unset PGPASSWORD

print_step "Writing php-app/.env"
cp -n "$PHP_APP_DIR/.env.example" "$PHP_APP_DIR/.env"
SESSION_SECRET="$(generate_secret)"
set_env_var "$PHP_APP_DIR/.env" "APP_ENV" "production"
set_env_var "$PHP_APP_DIR/.env" "APP_DEBUG" "false"
set_env_var "$PHP_APP_DIR/.env" "APP_URL" "$APP_URL"
set_env_var "$PHP_APP_DIR/.env" "SESSION_SECRET" "$SESSION_SECRET"
set_env_var "$PHP_APP_DIR/.env" "SESSION_SECURE_COOKIE" "$(bool_from_url "$APP_URL")"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_VERIFY_TLS" "true"
set_env_var "$PHP_APP_DIR/.env" "DB_HOST" "localhost"
set_env_var "$PHP_APP_DIR/.env" "DB_PORT" "5432"
set_env_var "$PHP_APP_DIR/.env" "DB_NAME" "$DB_NAME"
set_env_var "$PHP_APP_DIR/.env" "DB_USER" "$DB_USER"
set_env_var "$PHP_APP_DIR/.env" "DB_PASS" "$DB_PASS"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_BASE_URL" "$KEYCLOAK_BASE_URL"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_REALM" "$KEYCLOAK_REALM"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_CLIENT_ID" "$KEYCLOAK_CLIENT_ID"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_CLIENT_SECRET" "$KEYCLOAK_CLIENT_SECRET"
set_env_var "$PHP_APP_DIR/.env" "KEYCLOAK_REDIRECT_URI" "$APP_URL/auth/callback"
set_env_var "$PHP_APP_DIR/.env" "PYTHON_API_BASE_URL" "$PYTHON_API_BASE_URL"
set_env_var "$PHP_APP_DIR/.env" "PYTHON_API_KEY" "$PYTHON_API_KEY"
set_env_var "$PHP_APP_DIR/.env" "MINIO_ENDPOINT" "$MINIO_ENDPOINT"
set_env_var "$PHP_APP_DIR/.env" "MINIO_ACCESS_KEY" "$MINIO_ACCESS_KEY"
set_env_var "$PHP_APP_DIR/.env" "MINIO_SECRET_KEY" "$MINIO_SECRET_KEY"
chmod 640 "$PHP_APP_DIR/.env"

print_step "Installing PHP dependencies"
cd "$PHP_APP_DIR"
composer install --no-dev --optimize-autoloader

print_step "Configuring Apache virtual host"
cp "$REPO_DIR/deploy/apache/vhost.conf" /etc/apache2/sites-available/mxa-transcription.conf
sed -i "s|/var/www/gismartanalytics|$PHP_APP_DIR|g" /etc/apache2/sites-available/mxa-transcription.conf
a2enmod rewrite headers proxy_fcgi
a2ensite mxa-transcription.conf
a2dissite 000-default || true
systemctl reload apache2

echo "App server setup complete."

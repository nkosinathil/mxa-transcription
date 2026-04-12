#!/usr/bin/env bash
# shellcheck source=../lib/common.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh"

parse_non_interactive_flags "$@"
require_root
print_header "MXA Transcription - SSO Server Setup"

KC_VERSION="${KC_VERSION:-26.1.3}"
KC_ADMIN="${KC_ADMIN:-admin}"
KC_DB_NAME="${KC_DB_NAME:-keycloak_db}"
KC_DB_USER="${KC_DB_USER:-keycloak_user}"
REALM_NAME="${REALM_NAME:-}"
CLIENT_ID="${CLIENT_ID:-transcription-web}"
APP_URL="${APP_URL:-https://transcription.example.com}"
KC_ADMIN_PASS="${KC_ADMIN_PASS:-}"
KC_DB_PASS="${KC_DB_PASS:-}"

if [[ "${NON_INTERACTIVE}" == "true" ]]; then
  require_env_vars KC_ADMIN_PASS KC_DB_PASS REALM_NAME
else
  KC_VERSION="$(prompt_default "Keycloak version" "${KC_VERSION}")"
  KC_ADMIN="$(prompt_default "Keycloak admin username" "${KC_ADMIN}")"
  if [[ -z "${KC_ADMIN_PASS}" ]]; then
    KC_ADMIN_PASS="$(prompt_secret_confirm "Keycloak admin password")"
  fi
  KC_DB_NAME="$(prompt_default "Keycloak database name" "${KC_DB_NAME}")"
  KC_DB_USER="$(prompt_default "Keycloak database user" "${KC_DB_USER}")"
  if [[ -z "${KC_DB_PASS}" ]]; then
    KC_DB_PASS="$(prompt_secret_confirm "Keycloak database password")"
  fi
  REALM_NAME="$(prompt_required "Realm name for MXA")"
  CLIENT_ID="$(prompt_default "Client ID" "${CLIENT_ID}")"
  APP_URL="$(prompt_default "Application URL (used for redirect URIs)" "${APP_URL}")"
fi

print_step "Install runtime dependencies"
apt-get update
apt-get install -y openjdk-21-jre-headless postgresql postgresql-contrib curl wget jq

print_step "Configure Keycloak database"
systemctl enable --now postgresql
sudo -u postgres psql -c "CREATE DATABASE ${KC_DB_NAME};" 2>/dev/null || print_warn "Database ${KC_DB_NAME} already exists"
sudo -u postgres psql -c "CREATE USER ${KC_DB_USER} WITH PASSWORD '${KC_DB_PASS}';" 2>/dev/null || print_warn "User ${KC_DB_USER} already exists"
sudo -u postgres psql -c "ALTER USER ${KC_DB_USER} WITH PASSWORD '${KC_DB_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${KC_DB_NAME} TO ${KC_DB_USER};"
sudo -u postgres psql -d "${KC_DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${KC_DB_USER};"

KC_HOME="/opt/keycloak"
if [[ ! -d "${KC_HOME}" ]]; then
  print_step "Install Keycloak ${KC_VERSION}"
  cd /tmp
  wget -q "https://github.com/keycloak/keycloak/releases/download/${KC_VERSION}/keycloak-${KC_VERSION}.tar.gz" -O keycloak.tar.gz
  tar -xzf keycloak.tar.gz
  mv "keycloak-${KC_VERSION}" "${KC_HOME}"
  rm -f keycloak.tar.gz
fi

useradd -r -s /usr/sbin/nologin keycloak 2>/dev/null || true
chown -R keycloak:keycloak "${KC_HOME}"

print_step "Write Keycloak config"
cat > "${KC_HOME}/conf/keycloak.conf" <<EOF
db=postgres
db-url=jdbc:postgresql://localhost:5432/${KC_DB_NAME}
db-username=${KC_DB_USER}
db-password=${KC_DB_PASS}
http-enabled=true
http-port=8080
hostname-strict=false
proxy-headers=xforwarded
EOF
chown keycloak:keycloak "${KC_HOME}/conf/keycloak.conf"

print_step "Build Keycloak profile"
sudo -u keycloak "${KC_HOME}/bin/kc.sh" build --db=postgres

print_step "Install systemd service"
cat > /etc/systemd/system/keycloak.service <<EOF
[Unit]
Description=Keycloak Identity Provider
After=network.target postgresql.service

[Service]
Type=simple
User=keycloak
Group=keycloak
WorkingDirectory=${KC_HOME}
Environment=KC_BOOTSTRAP_ADMIN_USERNAME=${KC_ADMIN}
Environment=KC_BOOTSTRAP_ADMIN_PASSWORD=${KC_ADMIN_PASS}
ExecStart=${KC_HOME}/bin/kc.sh start
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now keycloak

print_step "Bootstrap realm/client/roles via admin CLI"
export KC_BOOTSTRAP_ADMIN_USERNAME="${KC_ADMIN}"
export KC_BOOTSTRAP_ADMIN_PASSWORD="${KC_ADMIN_PASS}"

for _ in {1..60}; do
  if curl -fsS "http://localhost:8080/health/ready" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

KCADM="${KC_HOME}/bin/kcadm.sh"
sudo -u keycloak "${KCADM}" config credentials --server "http://localhost:8080" --realm master --user "${KC_ADMIN}" --password "${KC_ADMIN_PASS}"

if ! sudo -u keycloak "${KCADM}" get realms/"${REALM_NAME}" >/dev/null 2>&1; then
  sudo -u keycloak "${KCADM}" create realms -s realm="${REALM_NAME}" -s enabled=true
fi

if ! sudo -u keycloak "${KCADM}" get clients -r "${REALM_NAME}" -q clientId="${CLIENT_ID}" --fields id,clientId | rg "\"clientId\"\\s*:\\s*\"${CLIENT_ID}\"" >/dev/null 2>&1; then
  sudo -u keycloak "${KCADM}" create clients -r "${REALM_NAME}" \
    -s clientId="${CLIENT_ID}" \
    -s enabled=true \
    -s protocol="openid-connect" \
    -s publicClient=false \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=false \
    -s "redirectUris=[\"${APP_URL}/auth/callback\"]" \
    -s "webOrigins=[\"${APP_URL}\"]" \
    -s "attributes.post.logout.redirect.uris=${APP_URL}/*"
fi

for role in admin analyst viewer; do
  if ! sudo -u keycloak "${KCADM}" get "roles/${role}" -r "${REALM_NAME}" >/dev/null 2>&1; then
    sudo -u keycloak "${KCADM}" create roles -r "${REALM_NAME}" -s name="${role}"
  fi
done

CLIENT_UUID="$(sudo -u keycloak "${KCADM}" get clients -r "${REALM_NAME}" -q clientId="${CLIENT_ID}" --fields id --format csv --noquotes | head -n1)"
CLIENT_SECRET="$(sudo -u keycloak "${KCADM}" get "clients/${CLIENT_UUID}/client-secret" -r "${REALM_NAME}" --fields value --format csv --noquotes | head -n1)"

print_header "SSO server setup complete"
printf "Realm: %s\nClient ID: %s\nClient Secret: %s\n" "${REALM_NAME}" "${CLIENT_ID}" "${CLIENT_SECRET}"

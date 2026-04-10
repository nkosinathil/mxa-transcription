#!/bin/bash
# =============================================================================
# MXA Transcription - SSO Server Setup (192.168.1.59)
# =============================================================================
# This script sets up the Keycloak SSO server
#
# Components installed/configured:
#   - Java JRE (required for Keycloak)
#   - PostgreSQL (Keycloak database)
#   - Keycloak server
#   - Realm and client configuration
#
# Usage:
#   sudo ./setup-sso-server.sh
# =============================================================================

set -e  # Exit on error

# Must run as root for system package installation
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================================${NC}"
echo -e "${BLUE}MXA Transcription - SSO Server Setup${NC}"
echo -e "${BLUE}Server: 192.168.1.59 (Keycloak)${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""

# =============================================================================
# Interactive Configuration
# =============================================================================
echo -e "${BLUE}Configuration${NC}"
echo ""

read -p "Keycloak version [23.0.7]: " KC_VERSION
KC_VERSION=${KC_VERSION:-23.0.7}

read -p "Keycloak admin username [admin]: " KC_ADMIN
KC_ADMIN=${KC_ADMIN:-admin}

while true; do
    read -sp "Keycloak admin password: " KC_ADMIN_PASS
    echo ""
    read -sp "Confirm password: " KC_ADMIN_PASS_CONFIRM
    echo ""
    if [ "$KC_ADMIN_PASS" = "$KC_ADMIN_PASS_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

read -p "Keycloak database name [keycloak_db]: " KC_DB_NAME
KC_DB_NAME=${KC_DB_NAME:-keycloak_db}

read -p "Keycloak database user [keycloak_user]: " KC_DB_USER
KC_DB_USER=${KC_DB_USER:-keycloak_user}

while true; do
    read -sp "Keycloak database password: " KC_DB_PASS
    echo ""
    read -sp "Confirm password: " KC_DB_PASS_CONFIRM
    echo ""
    if [ "$KC_DB_PASS" = "$KC_DB_PASS_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

read -p "Realm name for MXA Transcription: " REALM_NAME
while [ -z "$REALM_NAME" ]; do
    echo -e "${RED}Realm name is required${NC}"
    read -p "Realm name for MXA Transcription: " REALM_NAME
done

read -p "Client ID [transcription-web]: " CLIENT_ID
CLIENT_ID=${CLIENT_ID:-transcription-web}

echo ""

# =============================================================================
# Step 1: Install system packages
# =============================================================================
echo -e "${BLUE}Step 1: Installing system packages...${NC}"

apt-get update

# Install Java (required for Keycloak)
apt-get install -y openjdk-17-jre-headless

echo -e "${GREEN}  ✓ Java installed${NC}"

# Install PostgreSQL for Keycloak database
apt-get install -y postgresql postgresql-contrib

echo -e "${GREEN}  ✓ PostgreSQL installed${NC}"

echo ""

# =============================================================================
# Step 2: Configure PostgreSQL
# =============================================================================
echo -e "${BLUE}Step 2: Configuring PostgreSQL...${NC}"

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create database and user for Keycloak
sudo -u postgres psql -c "CREATE DATABASE $KC_DB_NAME;" 2>/dev/null || echo -e "${YELLOW}  ⚠ Database $KC_DB_NAME already exists${NC}"
sudo -u postgres psql -c "CREATE USER $KC_DB_USER WITH PASSWORD '$KC_DB_PASS';" 2>/dev/null || echo -e "${YELLOW}  ⚠ User $KC_DB_USER already exists${NC}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $KC_DB_NAME TO $KC_DB_USER;" 2>/dev/null

echo -e "${GREEN}  ✓ Database configured${NC}"

echo ""

# =============================================================================
# Step 3: Install Keycloak
# =============================================================================
echo -e "${BLUE}Step 3: Installing Keycloak...${NC}"

# Create keycloak user
useradd -r -s /bin/false keycloak 2>/dev/null || echo -e "${YELLOW}  ⚠ keycloak user already exists${NC}"

# Download and install Keycloak
KC_HOME="/opt/keycloak"
if [ ! -d "$KC_HOME" ]; then
    echo -e "${BLUE}  → Downloading Keycloak $KC_VERSION...${NC}"
    cd /tmp
    wget -q https://github.com/keycloak/keycloak/releases/download/$KC_VERSION/keycloak-$KC_VERSION.tar.gz
    tar -xzf keycloak-$KC_VERSION.tar.gz
    mv keycloak-$KC_VERSION "$KC_HOME"
    chown -R keycloak:keycloak "$KC_HOME"
    rm keycloak-$KC_VERSION.tar.gz
    echo -e "${GREEN}  ✓ Keycloak installed to $KC_HOME${NC}"
else
    echo -e "${YELLOW}  ⚠ Keycloak already installed at $KC_HOME${NC}"
fi

cd "$SCRIPT_DIR"

echo ""

# =============================================================================
# Step 4: Configure Keycloak
# =============================================================================
echo -e "${BLUE}Step 4: Configuring Keycloak...${NC}"

# Download PostgreSQL JDBC driver
if [ ! -f "$KC_HOME/providers/postgresql.jar" ]; then
    echo -e "${BLUE}  → Downloading PostgreSQL JDBC driver...${NC}"
    mkdir -p "$KC_HOME/providers"
    wget -q https://jdbc.postgresql.org/download/postgresql-42.7.1.jar -O "$KC_HOME/providers/postgresql.jar"
    chown keycloak:keycloak "$KC_HOME/providers/postgresql.jar"
    echo -e "${GREEN}  ✓ JDBC driver installed${NC}"
fi

# Create Keycloak configuration file
cat > "$KC_HOME/conf/keycloak.conf" << EOF
# Database configuration
db=postgres
db-url=jdbc:postgresql://localhost:5432/$KC_DB_NAME
db-username=$KC_DB_USER
db-password=$KC_DB_PASS

# HTTP configuration
http-enabled=true
http-port=8080
hostname=192.168.1.59

# Admin credentials
# These are only used for initial setup
EOF

chown keycloak:keycloak "$KC_HOME/conf/keycloak.conf"

echo -e "${GREEN}  ✓ Keycloak configured${NC}"

# Build Keycloak (required after configuration changes)
echo -e "${BLUE}  → Building Keycloak configuration...${NC}"
sudo -u keycloak "$KC_HOME/bin/kc.sh" build --db=postgres

echo ""

# =============================================================================
# Step 5: Create systemd service
# =============================================================================
echo -e "${BLUE}Step 5: Creating systemd service...${NC}"

cat > /etc/systemd/system/keycloak.service << EOF
[Unit]
Description=Keycloak Application Server
After=network.target postgresql.service

[Service]
Type=idle
User=keycloak
Group=keycloak
Environment="KC_BOOTSTRAP_ADMIN_USERNAME=$KC_ADMIN"
Environment="KC_BOOTSTRAP_ADMIN_PASSWORD=$KC_ADMIN_PASS"
ExecStart=$KC_HOME/bin/kc.sh start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Start Keycloak
systemctl daemon-reload
systemctl start keycloak
systemctl enable keycloak

echo -e "${GREEN}  ✓ Keycloak service started${NC}"
echo -e "${YELLOW}  → Waiting for Keycloak to start (this may take 30-60 seconds)...${NC}"

# Wait for Keycloak to be ready
for i in {1..60}; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Keycloak is ready${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 60 ]; then
        echo -e "${YELLOW}  ⚠ Keycloak may still be starting. Check: systemctl status keycloak${NC}"
    fi
done

echo ""

# =============================================================================
# Step 6: Configure Realm and Client (Manual Instructions)
# =============================================================================
echo -e "${BLUE}Step 6: Realm and Client Configuration${NC}"
echo ""
echo -e "${YELLOW}The following steps must be completed via the Keycloak Admin Console:${NC}"
echo ""
echo "  1. Access Keycloak Admin Console:"
echo "     http://192.168.1.59:8080/admin"
echo ""
echo "  2. Login with:"
echo "     Username: $KC_ADMIN"
echo "     Password: <your admin password>"
echo ""
echo "  3. Create a new Realm:"
echo "     - Click: Create Realm"
echo "     - Realm name: $REALM_NAME"
echo "     - Click: Create"
echo ""
echo "  4. Create a Client:"
echo "     - Go to: Clients → Create"
echo "     - Client type: OpenID Connect"
echo "     - Client ID: $CLIENT_ID"
echo "     - Click: Next"
echo ""
echo "  5. Configure Client Settings:"
echo "     - Client authentication: ON"
echo "     - Standard flow: ON (enabled)"
echo "     - Direct access grants: OFF"
echo "     - Click: Next"
echo ""
echo "  6. Set Valid Redirect URIs:"
echo "     - Valid redirect URIs: http://192.168.1.66/auth/callback"
echo "     - Valid post logout redirect URIs: http://192.168.1.66/"
echo "     - Web origins: http://192.168.1.66"
echo "     - Click: Save"
echo ""
echo "  7. Get Client Secret:"
echo "     - Go to: Clients → $CLIENT_ID → Credentials"
echo "     - Copy the Client Secret"
echo "     - Update this value in php-app/.env on 192.168.1.66"
echo ""
echo "  8. Create Realm Roles:"
echo "     - Go to: Realm roles → Create role"
echo "     - Create three roles: admin, analyst, viewer"
echo ""
echo "  9. Create Test Users:"
echo "     - Go to: Users → Add user"
echo "     - Create users and assign roles via Role mapping"
echo ""

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=========================================================================${NC}"
echo -e "${GREEN}SSO Server Setup Complete!${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""
echo -e "${YELLOW}Service Status:${NC}"
systemctl status keycloak --no-pager | grep "Active:" || true
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo "  Admin Console:  http://192.168.1.59:8080/admin"
echo "  Realm URL:      http://192.168.1.59:8080/realms/$REALM_NAME"
echo ""
echo -e "${YELLOW}Admin Credentials:${NC}"
echo "  Username: $KC_ADMIN"
echo "  Password: <as configured>"
echo ""
echo -e "${YELLOW}Configuration Values for App Server:${NC}"
echo "  KEYCLOAK_BASE_URL=http://192.168.1.59:8080"
echo "  KEYCLOAK_REALM=$REALM_NAME"
echo "  KEYCLOAK_CLIENT_ID=$CLIENT_ID"
echo "  KEYCLOAK_CLIENT_SECRET=<copy from Keycloak Admin Console>"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  sudo systemctl status keycloak"
echo "  sudo systemctl restart keycloak"
echo "  sudo journalctl -u keycloak -f"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Complete realm and client configuration (see instructions above)"
echo "  2. Update KEYCLOAK_CLIENT_SECRET in php-app/.env on 192.168.1.66"
echo "  3. Create users and assign roles"
echo ""

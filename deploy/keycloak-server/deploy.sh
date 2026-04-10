#!/bin/bash
# Deployment script for Keycloak SSO Server (192.168.1.59)
# Run as root or with sudo

set -e  # Exit on error

echo "======================================"
echo "MXA Transcription - Keycloak SSO Setup"
echo "Server: 192.168.1.59"
echo "======================================"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Variables
KEYCLOAK_VERSION="21.1.2"
KEYCLOAK_DIR="/opt/keycloak"
USER="keycloak"

# Step 1: Update system
echo "[1/7] Updating system packages..."
apt-get update
apt-get upgrade -y

# Step 2: Install Java
echo "[2/7] Installing Java..."
apt-get install -y openjdk-17-jdk curl unzip

# Verify Java installation
java -version

# Step 3: Create Keycloak user
echo "[3/7] Creating Keycloak user..."
if ! id "$USER" &>/dev/null; then
    useradd -r -s /bin/false $USER
    echo "User $USER created"
else
    echo "User $USER already exists"
fi

# Step 4: Download and install Keycloak
echo "[4/7] Downloading Keycloak..."
cd /opt
wget https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.zip
unzip keycloak-${KEYCLOAK_VERSION}.zip
mv keycloak-${KEYCLOAK_VERSION} keycloak
rm keycloak-${KEYCLOAK_VERSION}.zip

# Change ownership
chown -R $USER:$USER $KEYCLOAK_DIR

# Step 5: Create admin user
echo "[5/7] Creating Keycloak admin user..."
cd $KEYCLOAK_DIR
sudo -u $USER $KEYCLOAK_DIR/bin/kc.sh bootstrap-admin -u admin -p admin
echo "IMPORTANT: Change the admin password after first login!"

# Step 6: Configure Keycloak systemd service
echo "[6/7] Creating Keycloak systemd service..."
cat > /etc/systemd/system/keycloak.service <<'KEYCLOAK_SERVICE'
[Unit]
Description=Keycloak SSO Server
After=network.target

[Service]
Type=simple
User=keycloak
Group=keycloak
WorkingDirectory=/opt/keycloak
ExecStart=/opt/keycloak/bin/kc.sh start-dev --http-host=0.0.0.0 --http-port=8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
KEYCLOAK_SERVICE

# Step 7: Enable and start Keycloak
echo "[7/7] Starting Keycloak..."
systemctl daemon-reload
systemctl enable keycloak
systemctl start keycloak

# Wait for Keycloak to start
echo "Waiting for Keycloak to start..."
sleep 30

echo
echo "======================================"
echo "Keycloak SSO Deployment Complete!"
echo "======================================"
echo
echo "Keycloak Admin Console: http://192.168.1.59:8080"
echo "Default admin credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo
echo "IMPORTANT: Change the admin password immediately!"
echo
echo "Next steps:"
echo "1. Login to Keycloak admin console"
echo "2. Create realm: mxa-transcription"
echo "3. Create client: mxa-transcription-client"
echo "   - Client Protocol: openid-connect"
echo "   - Access Type: confidential"
echo "   - Valid Redirect URIs: http://192.168.1.66/*"
echo "   - Web Origins: http://192.168.1.66"
echo "4. Create roles: user, admin, operator"
echo "5. Create users and assign roles"
echo "6. Copy client secret to PHP server .env file"
echo
echo "Service management:"
echo "  - Start: systemctl start keycloak"
echo "  - Stop: systemctl stop keycloak"
echo "  - Restart: systemctl restart keycloak"
echo "  - Status: systemctl status keycloak"
echo
echo "Logs:"
echo "  - View logs: journalctl -u keycloak -f"
echo

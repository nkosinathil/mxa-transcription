#!/bin/bash
# =============================================================================
# MXA Transcription - App Server Setup (192.168.1.66)
# =============================================================================
# This script sets up the PHP/Apache/PostgreSQL server
#
# Components installed/configured:
#   - PHP 8.1+ with required extensions
#   - Apache web server
#   - PostgreSQL database
#   - Composer dependencies
#   - Environment configuration
#
# Usage:
#   sudo ./setup-app-server.sh
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
echo -e "${BLUE}MXA Transcription - App Server Setup${NC}"
echo -e "${BLUE}Server: 192.168.1.66 (PHP/Apache/PostgreSQL)${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""

# =============================================================================
# Interactive Configuration
# =============================================================================
echo -e "${BLUE}Configuration${NC}"
echo ""

read -p "PostgreSQL database name [transcription_db]: " DB_NAME
DB_NAME=${DB_NAME:-transcription_db}

read -p "PostgreSQL database user [transcription_user]: " DB_USER
DB_USER=${DB_USER:-transcription_user}

while true; do
    read -sp "PostgreSQL database password: " DB_PASS
    echo ""
    read -sp "Confirm password: " DB_PASS_CONFIRM
    echo ""
    if [ "$DB_PASS" = "$DB_PASS_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done

read -p "Keycloak server URL [http://192.168.1.59:8080]: " KEYCLOAK_URL
KEYCLOAK_URL=${KEYCLOAK_URL:-http://192.168.1.59:8080}

read -p "Keycloak realm name: " KEYCLOAK_REALM
while [ -z "$KEYCLOAK_REALM" ]; do
    echo -e "${RED}Realm name is required${NC}"
    read -p "Keycloak realm name: " KEYCLOAK_REALM
done

read -p "Keycloak client ID [transcription-web]: " KEYCLOAK_CLIENT_ID
KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-transcription-web}

read -sp "Keycloak client secret: " KEYCLOAK_CLIENT_SECRET
echo ""
while [ -z "$KEYCLOAK_CLIENT_SECRET" ]; do
    echo -e "${RED}Client secret is required${NC}"
    read -sp "Keycloak client secret: " KEYCLOAK_CLIENT_SECRET
    echo ""
done

read -p "Python API server URL [http://192.168.1.90:8000]: " PYTHON_API_URL
PYTHON_API_URL=${PYTHON_API_URL:-http://192.168.1.90:8000}

read -p "MinIO endpoint [192.168.1.90:9000]: " MINIO_ENDPOINT
MINIO_ENDPOINT=${MINIO_ENDPOINT:-192.168.1.90:9000}

read -p "MinIO access key [minioadmin]: " MINIO_ACCESS_KEY
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-minioadmin}

read -sp "MinIO secret key [minioadmin]: " MINIO_SECRET_KEY
echo ""
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-minioadmin}

echo ""

# =============================================================================
# Step 1: Install system packages
# =============================================================================
echo -e "${BLUE}Step 1: Installing system packages...${NC}"

apt-get update

# Install PHP 8.1+ and required extensions
apt-get install -y \
    php \
    php-fpm \
    php-pgsql \
    php-curl \
    php-json \
    php-mbstring \
    php-xml \
    apache2 \
    libapache2-mod-php

echo -e "${GREEN}  ✓ PHP and Apache installed${NC}"

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib

echo -e "${GREEN}  ✓ PostgreSQL installed${NC}"

# Install Composer
if ! command -v composer &> /dev/null; then
    echo -e "${BLUE}  → Installing Composer...${NC}"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo -e "${GREEN}  ✓ Composer installed${NC}"
else
    echo -e "${GREEN}  ✓ Composer already installed${NC}"
fi

echo ""

# =============================================================================
# Step 2: Configure PostgreSQL
# =============================================================================
echo -e "${BLUE}Step 2: Configuring PostgreSQL...${NC}"

# Start PostgreSQL if not running
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo -e "${YELLOW}  ⚠ Database $DB_NAME already exists${NC}"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || echo -e "${YELLOW}  ⚠ User $DB_USER already exists${NC}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null

echo -e "${GREEN}  ✓ Database configured${NC}"

# Run migrations
if [ -f "database/schema.sql" ]; then
    echo -e "${BLUE}  → Running database migrations...${NC}"
    export PGPASSWORD="$DB_PASS"
    psql -U "$DB_USER" -d "$DB_NAME" -f database/schema.sql 2>&1 | grep -v "ERROR.*already exists" || true
    unset PGPASSWORD
    echo -e "${GREEN}  ✓ Migrations completed${NC}"
fi

echo ""

# =============================================================================
# Step 3: Configure PHP application
# =============================================================================
echo -e "${BLUE}Step 3: Configuring PHP application...${NC}"

# Create .env file
if [ ! -f "php-app/.env" ]; then
    cp php-app/.env.example php-app/.env
    echo -e "${GREEN}  ✓ Created php-app/.env${NC}"
else
    echo -e "${YELLOW}  ⚠ php-app/.env already exists - will update values${NC}"
fi

# Generate secrets
SESSION_SECRET=$(php -r "echo bin2hex(random_bytes(32));")
PYTHON_API_KEY=$(php -r "echo bin2hex(random_bytes(32));")

# Update .env file with user-provided values
sed -i "s|APP_ENV=.*|APP_ENV=production|" php-app/.env
sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|" php-app/.env
sed -i "s|SESSION_SECRET=.*|SESSION_SECRET=$SESSION_SECRET|" php-app/.env
sed -i "s|DB_HOST=.*|DB_HOST=localhost|" php-app/.env
sed -i "s|DB_PORT=.*|DB_PORT=5432|" php-app/.env
sed -i "s|DB_NAME=.*|DB_NAME=$DB_NAME|" php-app/.env
sed -i "s|DB_USER=.*|DB_USER=$DB_USER|" php-app/.env
sed -i "s|DB_PASS=.*|DB_PASS=$DB_PASS|" php-app/.env
sed -i "s|KEYCLOAK_BASE_URL=.*|KEYCLOAK_BASE_URL=$KEYCLOAK_URL|" php-app/.env
sed -i "s|KEYCLOAK_REALM=.*|KEYCLOAK_REALM=$KEYCLOAK_REALM|" php-app/.env
sed -i "s|KEYCLOAK_CLIENT_ID=.*|KEYCLOAK_CLIENT_ID=$KEYCLOAK_CLIENT_ID|" php-app/.env
sed -i "s|KEYCLOAK_CLIENT_SECRET=.*|KEYCLOAK_CLIENT_SECRET=$KEYCLOAK_CLIENT_SECRET|" php-app/.env
sed -i "s|KEYCLOAK_REDIRECT_URI=.*|KEYCLOAK_REDIRECT_URI=http://192.168.1.66/auth/callback|" php-app/.env
sed -i "s|PYTHON_API_BASE_URL=.*|PYTHON_API_BASE_URL=$PYTHON_API_URL|" php-app/.env
sed -i "s|PYTHON_API_KEY=.*|PYTHON_API_KEY=$PYTHON_API_KEY|" php-app/.env
sed -i "s|MINIO_ENDPOINT=.*|MINIO_ENDPOINT=$MINIO_ENDPOINT|" php-app/.env
sed -i "s|MINIO_ACCESS_KEY=.*|MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY|" php-app/.env
sed -i "s|MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=$MINIO_SECRET_KEY|" php-app/.env

echo -e "${GREEN}  ✓ Environment configured${NC}"

# Save API key for Python server setup
echo "$PYTHON_API_KEY" > /tmp/mxa_api_key.txt
chmod 600 /tmp/mxa_api_key.txt
echo -e "${YELLOW}  → Python API key saved to /tmp/mxa_api_key.txt${NC}"
echo -e "${YELLOW}    Copy this file to the Python server and use it during setup${NC}"

# Create required directories
mkdir -p php-app/storage/logs
chown -R www-data:www-data php-app/storage
echo -e "${GREEN}  ✓ Created storage directories${NC}"

# Install PHP dependencies
cd php-app
echo -e "${BLUE}  → Installing PHP dependencies...${NC}"
composer install --no-dev --optimize-autoloader
cd ..
echo -e "${GREEN}  ✓ PHP dependencies installed${NC}"

echo ""

# =============================================================================
# Step 4: Configure Apache
# =============================================================================
echo -e "${BLUE}Step 4: Configuring Apache...${NC}"

# Enable required modules
a2enmod rewrite
a2enmod headers
a2enmod proxy_fcgi
systemctl restart apache2

echo -e "${GREEN}  ✓ Apache modules enabled${NC}"

# Create virtual host configuration
VHOST_FILE="/etc/apache2/sites-available/mxa-transcription.conf"
if [ ! -f "$VHOST_FILE" ]; then
    cat > "$VHOST_FILE" << 'EOF'
<VirtualHost *:80>
    ServerName 192.168.1.66
    DocumentRoot /var/www/mxa-transcription/php-app/public

    <Directory /var/www/mxa-transcription/php-app/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mxa-error.log
    CustomLog ${APACHE_LOG_DIR}/mxa-access.log combined
</VirtualHost>
EOF
    
    # Update DocumentRoot to actual path
    sed -i "s|/var/www/mxa-transcription|$SCRIPT_DIR|g" "$VHOST_FILE"
    
    # Enable the site
    a2ensite mxa-transcription
    a2dissite 000-default
    
    systemctl reload apache2
    
    echo -e "${GREEN}  ✓ Apache virtual host configured${NC}"
else
    echo -e "${YELLOW}  ⚠ Virtual host already exists: $VHOST_FILE${NC}"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=========================================================================${NC}"
echo -e "${GREEN}App Server Setup Complete!${NC}"
echo -e "${BLUE}=========================================================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Copy the API key to Python server:"
echo "     scp /tmp/mxa_api_key.txt user@192.168.1.90:/tmp/"
echo ""
echo "  2. Configure Keycloak:"
echo "     - Create client: $KEYCLOAK_CLIENT_ID"
echo "     - Set redirect URI: http://192.168.1.66/auth/callback"
echo "     - Create roles: admin, analyst, viewer"
echo ""
echo "  3. Test the application:"
echo "     http://192.168.1.66"
echo ""
echo "  4. Check Apache logs if needed:"
echo "     tail -f /var/log/apache2/mxa-error.log"
echo ""
echo -e "Database: ${GREEN}$DB_NAME${NC} (user: $DB_USER)"
echo -e "PHP Config: ${GREEN}php-app/.env${NC}"
echo ""

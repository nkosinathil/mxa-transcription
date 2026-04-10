#!/bin/bash
# Deployment script for PHP Frontend Server (192.168.1.66)
# Run as root or with sudo

set -e  # Exit on error

echo "======================================"
echo "MXA Transcription - PHP Server Setup"
echo "Server: 192.168.1.66"
echo "======================================"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Variables
APP_DIR="/var/www/html/mxa-transcription"
REPO_URL="https://github.com/nkosinathil/mxa-transcription.git"
BRANCH="main"

# Step 1: Update system
echo "[1/10] Updating system packages..."
apt-get update
apt-get upgrade -y

# Step 2: Install dependencies
echo "[2/10] Installing dependencies..."
apt-get install -y \
    apache2 \
    php8.1 \
    php8.1-cli \
    php8.1-common \
    php8.1-curl \
    php8.1-mbstring \
    php8.1-pgsql \
    php8.1-xml \
    postgresql-14 \
    postgresql-client-14 \
    git \
    curl \
    unzip

# Step 3: Configure PostgreSQL
echo "[3/10] Configuring PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql

# Create database and user
sudo -u postgres psql <<EOF
-- Create database
CREATE DATABASE mxa_transcription;

-- Create user
CREATE USER mxa_transcription WITH PASSWORD 'CHANGE_THIS_PASSWORD';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE mxa_transcription TO mxa_transcription;
EOF

# Import schema
echo "[4/10] Importing database schema..."
cd $APP_DIR
sudo -u postgres psql -d mxa_transcription -f database/migrations/001_initial_schema.sql

# Step 5: Clone repository
echo "[5/10] Cloning repository..."
if [ -d "$APP_DIR" ]; then
    echo "Directory exists, pulling latest changes..."
    cd $APP_DIR
    git pull origin $BRANCH
else
    git clone -b $BRANCH $REPO_URL $APP_DIR
    cd $APP_DIR
fi

# Step 6: Set up PHP environment
echo "[6/10] Configuring PHP environment..."
cp php-app/.env.example php-app/.env

# Update .env file (user should manually edit this)
echo "IMPORTANT: Edit php-app/.env with your actual credentials"

# Step 7: Set permissions
echo "[7/10] Setting file permissions..."
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR
chmod -R 775 $APP_DIR/php-app/storage

# Step 8: Configure Apache
echo "[8/10] Configuring Apache..."
cat > /etc/apache2/sites-available/mxa-transcription.conf <<'APACHE_CONF'
<VirtualHost *:80>
    ServerName 192.168.1.66
    DocumentRoot /var/www/html/mxa-transcription/php-app/public

    <Directory /var/www/html/mxa-transcription/php-app/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Rewrite rules for clean URLs
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.php [QSA,L]
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mxa-transcription-error.log
    CustomLog ${APACHE_LOG_DIR}/mxa-transcription-access.log combined
</VirtualHost>
APACHE_CONF

# Enable Apache modules
a2enmod rewrite
a2enmod headers

# Enable site
a2ensite mxa-transcription.conf
a2dissite 000-default.conf

# Step 9: Restart Apache
echo "[9/10] Restarting Apache..."
systemctl restart apache2
systemctl enable apache2

# Step 10: Final setup
echo "[10/10] Final setup..."
echo "Creating log files..."
touch $APP_DIR/php-app/storage/logs/app.log
chown www-data:www-data $APP_DIR/php-app/storage/logs/app.log

echo
echo "======================================"
echo "PHP Server Deployment Complete!"
echo "======================================"
echo
echo "Next steps:"
echo "1. Edit $APP_DIR/php-app/.env with your configuration"
echo "2. Update database password in PostgreSQL"
echo "3. Configure Keycloak settings in .env"
echo "4. Test the application: http://192.168.1.66"
echo
echo "Logs:"
echo "  - Apache error: /var/log/apache2/mxa-transcription-error.log"
echo "  - Application: $APP_DIR/php-app/storage/logs/app.log"
echo

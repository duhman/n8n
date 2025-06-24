#!/bin/bash

# n8n Production Setup Script
# This script helps with initial setup of n8n production environment

set -e

echo "======================================"
echo "n8n Production Setup Script"
echo "======================================"
echo ""

# Check if .env already exists
if [ -f .env ]; then
    echo "Warning: .env file already exists!"
    read -p "Do you want to overwrite it? (yes/no): " OVERWRITE
    if [ "$OVERWRITE" != "yes" ]; then
        echo "Setup cancelled. Please backup or remove existing .env file."
        exit 1
    fi
fi

# Copy .env.example to .env
cp .env.example .env

# Generate encryption key
echo "Generating encryption key..."
ENCRYPTION_KEY=$(openssl rand -hex 32)
sed -i.bak "s/your-32-byte-encryption-key-here/${ENCRYPTION_KEY}/" .env

# Generate secure database password
echo "Generating secure database password..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
sed -i.bak "s/ChangeThisStrongPassword123!/${DB_PASSWORD}/" .env

# Configure domain
read -p "Enter your domain name (e.g., n8n.example.com) or press Enter for localhost: " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN="localhost"
fi
sed -i.bak "s/N8N_HOST=localhost/N8N_HOST=${DOMAIN}/" .env

# Configure webhook URL
if [ "$DOMAIN" = "localhost" ]; then
    WEBHOOK="http://localhost:5678/"
else
    read -p "Will you use HTTPS? (yes/no): " USE_HTTPS
    if [ "$USE_HTTPS" = "yes" ]; then
        WEBHOOK="https://${DOMAIN}/"
        sed -i.bak "s/N8N_PROTOCOL=http/N8N_PROTOCOL=https/" .env
    else
        WEBHOOK="http://${DOMAIN}/"
    fi
fi
sed -i.bak "s|WEBHOOK_URL=http://localhost:5678/|WEBHOOK_URL=${WEBHOOK}|" .env

# Configure timezone
read -p "Enter your timezone (e.g., America/New_York, Europe/London): " TIMEZONE
if [ ! -z "$TIMEZONE" ]; then
    sed -i.bak "s/GENERIC_TIMEZONE=America\/New_York/GENERIC_TIMEZONE=${TIMEZONE//\//\\/}/" .env
    sed -i.bak "s/TZ=America\/New_York/TZ=${TIMEZONE//\//\\/}/" .env
fi

# Clean up backup files
rm -f .env.bak

# Create necessary directories
echo "Creating data directories..."
mkdir -p data/{n8n,postgres} backups local-files

# Set permissions
chmod 600 .env
chmod +x backup.sh restore.sh

echo ""
echo "======================================"
echo "Setup completed successfully!"
echo "======================================"
echo ""
echo "Generated configuration:"
echo "- Domain: ${DOMAIN}"
echo "- Webhook URL: ${WEBHOOK}"
echo "- Timezone: ${TIMEZONE:-America/New_York}"
echo "- Encryption key: [HIDDEN - stored in .env]"
echo "- Database password: [HIDDEN - stored in .env]"
echo ""
echo "Next steps:"
echo "1. Review and adjust settings in .env if needed"
echo "2. Start n8n: docker-compose up -d"
echo "3. Access n8n at: http://localhost:5678"
echo "4. Create your admin account on first access"
echo ""
echo "For SSL/TLS setup, see docker-compose.override.yml.example"
#!/bin/bash

# n8n Deployment Script for Hetzner
# This script deploys n8n using the production Docker setup

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Variables
N8N_DIR="/opt/n8n"
REPO_URL="https://github.com/duhman/n8n.git"
PRODUCTION_DIR="$N8N_DIR/n8n-production"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting n8n deployment..."

# Clone the repository
log "Cloning n8n repository..."
cd /opt
if [ -d "$N8N_DIR" ]; then
    warning "n8n directory already exists. Backing up..."
    mv "$N8N_DIR" "$N8N_DIR.backup.$(date +%Y%m%d_%H%M%S)"
fi

git clone "$REPO_URL" n8n
chown -R n8n:n8n "$N8N_DIR"

# Navigate to production directory
cd "$PRODUCTION_DIR"

# Check if .env file exists
if [ ! -f ".env" ]; then
    log "Creating .env file from template..."
    cp .env.example .env
    
    # Generate secure passwords and keys
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
    
    # Update .env file with generated values
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
    sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$POSTGRES_PASSWORD/" .env
    
    info "Generated secure passwords and encryption key"
    
    # Get domain information
    echo ""
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
    
    # Update .env with domain
    sed -i "s/N8N_HOST=.*/N8N_HOST=$DOMAIN_NAME/" .env
    sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=https://$DOMAIN_NAME/|" .env
    
    # Email configuration
    echo ""
    read -p "Do you want to configure email settings? (y/n): " CONFIGURE_EMAIL
    if [[ "$CONFIGURE_EMAIL" =~ ^[Yy]$ ]]; then
        read -p "SMTP Host: " SMTP_HOST
        read -p "SMTP Port (usually 587 or 465): " SMTP_PORT
        read -p "SMTP Username: " SMTP_USER
        read -s -p "SMTP Password: " SMTP_PASS
        echo ""
        read -p "Default sender email: " DEFAULT_EMAIL
        
        # Update .env with email settings
        sed -i "s/N8N_EMAIL_MODE=.*/N8N_EMAIL_MODE=smtp/" .env
        sed -i "s/N8N_SMTP_HOST=.*/N8N_SMTP_HOST=$SMTP_HOST/" .env
        sed -i "s/N8N_SMTP_PORT=.*/N8N_SMTP_PORT=$SMTP_PORT/" .env
        sed -i "s/N8N_SMTP_USER=.*/N8N_SMTP_USER=$SMTP_USER/" .env
        sed -i "s/N8N_SMTP_PASS=.*/N8N_SMTP_PASS=$SMTP_PASS/" .env
        sed -i "s/N8N_DEFAULT_EMAIL=.*/N8N_DEFAULT_EMAIL=$DEFAULT_EMAIL/" .env
    fi
else
    log ".env file already exists, using existing configuration"
    # Extract domain from existing .env
    DOMAIN_NAME=$(grep N8N_HOST .env | cut -d'=' -f2)
fi

# Set proper permissions
chown n8n:n8n .env
chmod 600 .env

# Create data directories
log "Creating data directories..."
mkdir -p data/postgres
mkdir -p data/n8n
mkdir -p local-files
chown -R n8n:n8n data/
chown -R n8n:n8n local-files/

# Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/n8n << EOF
# Upstream configuration
upstream n8n {
    server localhost:5678;
}

# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    
    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all HTTP traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL configuration will be added by certbot
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Proxy settings
    client_max_body_size 100M;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    
    # Main location
    location / {
        proxy_pass http://n8n;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start n8n with Docker Compose
log "Starting n8n with Docker Compose..."
cd "$PRODUCTION_DIR"
sudo -u n8n docker compose pull
sudo -u n8n docker compose up -d

# Wait for services to start
log "Waiting for services to start..."
sleep 10

# Check if services are running
if sudo -u n8n docker compose ps | grep -q "Up"; then
    log "n8n services started successfully!"
else
    error "Failed to start n8n services. Check logs with: docker compose logs"
fi

# Create systemd service for auto-start
log "Creating systemd service..."
cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n workflow automation
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=n8n
Group=n8n
WorkingDirectory=$PRODUCTION_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable n8n

# Set up cron job for Docker cleanup
log "Setting up Docker cleanup cron job..."
cat > /etc/cron.daily/docker-cleanup << 'EOF'
#!/bin/bash
# Clean up unused Docker resources
docker system prune -af --volumes
EOF
chmod +x /etc/cron.daily/docker-cleanup

# Display status
log "Deployment complete!"
echo ""
echo "==================================="
echo "n8n Deployment Status:"
echo "==================================="
sudo -u n8n docker compose ps
echo ""
echo "==================================="
echo "Next Steps:"
echo "==================================="
echo "1. Configure DNS: Point $DOMAIN_NAME to $(curl -s ifconfig.me)"
echo "2. Once DNS is propagated, run: certbot --nginx -d $DOMAIN_NAME"
echo "3. Access n8n at: http://$(curl -s ifconfig.me):5678"
echo "   (or https://$DOMAIN_NAME after SSL setup)"
echo "4. Set up your first admin user in n8n"
echo "5. Run backup-setup.sh to configure automated backups"
echo ""
echo "==================================="
echo "Important Information:"
echo "==================================="
echo "n8n directory: $N8N_DIR"
echo "Production config: $PRODUCTION_DIR"
echo "Data directory: $PRODUCTION_DIR/data"
echo "Logs: docker compose logs -f"
echo ""
echo "Encryption key has been generated and saved."
echo "KEEP YOUR .env FILE SECURE!"
echo "==================================="

# Save deployment info
cat > "$N8N_DIR/deployment-info.txt" << EOF
Deployment Date: $(date)
Server IP: $(curl -s ifconfig.me)
Domain: $DOMAIN_NAME
n8n Directory: $N8N_DIR
Production Directory: $PRODUCTION_DIR
EOF

log "Deployment completed successfully!"
#!/bin/bash

# Fix Nginx Configuration for HTTP-only (fallback if SSL fails)
# This script creates a working HTTP-only configuration

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Get domain name
if [ -f "/opt/n8n/deployment-info.txt" ]; then
    DOMAIN_NAME=$(grep "Domain:" /opt/n8n/deployment-info.txt | cut -d' ' -f2)
else
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
fi

log "Creating HTTP-only nginx configuration for $DOMAIN_NAME..."

# Create HTTP-only configuration
cat > /etc/nginx/sites-available/n8n << EOF
# HTTP-only configuration for $DOMAIN_NAME
# Rate limiting (relaxed for multi-user environments)
limit_req_zone \$binary_remote_addr zone=n8n_limit:10m rate=30r/s;
limit_conn_zone \$binary_remote_addr zone=n8n_conn:10m;

# Upstream configuration
upstream n8n {
    server localhost:5678;
}

# Main server configuration
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    
    # Security headers (for HTTP)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Rate limiting (allows bursts for legitimate multi-user activity)
    limit_req zone=n8n_limit burst=50 nodelay;
    limit_conn n8n_conn 25;
    
    # Proxy settings
    client_max_body_size 100M;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    
    # Logging
    access_log /var/log/nginx/n8n_access.log;
    error_log /var/log/nginx/n8n_error.log;
    
    # Let's Encrypt verification (for future SSL setup)
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
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
    
    # Deny access to sensitive files
    location ~ /\\.(?!well-known) {
        deny all;
    }
}

# Default server to catch all other requests
server {
    listen 80 default_server;
    server_name _;
    return 444;
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Test and reload nginx
log "Testing nginx configuration..."
if nginx -t; then
    log "Nginx configuration is valid"
    systemctl reload nginx
    log "Nginx reloaded successfully"
else
    error "Nginx configuration test failed"
fi

# Create certbot directory for future SSL setup
mkdir -p /var/www/certbot

info "HTTP-only nginx configuration created successfully!"
info "n8n is now accessible at: http://$DOMAIN_NAME"
warning "This configuration uses HTTP only - not recommended for production"
info "To add SSL later, run: ./secure-server.sh"
info "Or try the troubleshooting script: ./troubleshoot-ssl.sh $DOMAIN_NAME"
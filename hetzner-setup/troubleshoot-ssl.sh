#!/bin/bash

# SSL Certificate Troubleshooting Script
# This script helps diagnose SSL certificate issues

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
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if domain is provided
if [ $# -eq 0 ]; then
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
else
    DOMAIN_NAME=$1
fi

log "Troubleshooting SSL certificate for $DOMAIN_NAME..."

# Check DNS resolution
log "Checking DNS resolution..."
if nslookup "$DOMAIN_NAME" > /dev/null 2>&1; then
    IP=$(nslookup "$DOMAIN_NAME" | grep -A 1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    if [ -n "$IP" ]; then
        info "Domain $DOMAIN_NAME resolves to: $IP"
        
        # Check if IP matches server IP
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || echo "Unknown")
        if [ "$IP" = "$SERVER_IP" ]; then
            info "✅ DNS points to this server ($SERVER_IP)"
        else
            warning "⚠️  DNS points to $IP but server IP is $SERVER_IP"
        fi
    else
        error "Could not determine IP address for $DOMAIN_NAME"
    fi
else
    error "❌ Domain $DOMAIN_NAME does not resolve"
fi

# Check port 80 accessibility
log "Checking port 80 accessibility..."
if nc -z -v -w5 "$DOMAIN_NAME" 80 2>/dev/null; then
    info "✅ Port 80 is accessible on $DOMAIN_NAME"
else
    warning "⚠️  Port 80 is not accessible on $DOMAIN_NAME"
fi

# Check if nginx is running
log "Checking nginx status..."
if systemctl is-active --quiet nginx; then
    info "✅ Nginx is running"
else
    error "❌ Nginx is not running"
fi

# Check nginx configuration
log "Checking nginx configuration..."
if nginx -t 2>/dev/null; then
    info "✅ Nginx configuration is valid"
else
    error "❌ Nginx configuration has errors:"
    nginx -t
fi

# Check if SSL certificate exists
log "Checking SSL certificate..."
if [ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    info "✅ SSL certificate exists for $DOMAIN_NAME"
    
    # Check certificate validity
    if openssl x509 -in "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" -text -noout | grep -q "Not After"; then
        EXPIRY=$(openssl x509 -in "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" -text -noout | grep "Not After" | sed 's/.*Not After : //')
        info "Certificate expires: $EXPIRY"
    fi
else
    error "❌ SSL certificate not found for $DOMAIN_NAME"
    info "Try running: certbot certonly --standalone -d $DOMAIN_NAME"
fi

# Check if n8n is accessible
log "Checking n8n accessibility..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200"; then
    info "✅ n8n is accessible on localhost:5678"
else
    warning "⚠️  n8n is not accessible on localhost:5678"
fi

# Check firewall status
log "Checking firewall status..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        info "✅ UFW firewall is active"
        if ufw status | grep -q "80/tcp"; then
            info "✅ Port 80 is allowed in firewall"
        else
            warning "⚠️  Port 80 is not allowed in firewall"
        fi
        if ufw status | grep -q "443/tcp"; then
            info "✅ Port 443 is allowed in firewall"
        else
            warning "⚠️  Port 443 is not allowed in firewall"
        fi
    else
        warning "⚠️  UFW firewall is not active"
    fi
else
    info "UFW not installed"
fi

log "SSL troubleshooting complete!"
log "If you're still having issues, try:"
log "1. Ensure DNS A record points to this server"
log "2. Wait 5-10 minutes for DNS propagation"
log "3. Check that ports 80 and 443 are not blocked by your hosting provider"
log "4. Try running: systemctl restart nginx"
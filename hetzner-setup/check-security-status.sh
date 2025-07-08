#!/bin/bash

# Check Security Status Script
# This script verifies that all security components are working correctly

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
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

log "Checking security status..."

# Check SSL certificate
if [ -f "/opt/n8n/deployment-info.txt" ]; then
    DOMAIN_NAME=$(grep "Domain:" /opt/n8n/deployment-info.txt | cut -d' ' -f2)
else
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
fi

log "Checking SSL certificate for $DOMAIN_NAME..."
if [ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    success "SSL certificate exists"
    
    # Check certificate expiry
    EXPIRY=$(openssl x509 -in "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" -text -noout | grep "Not After" | sed 's/.*Not After : //')
    info "Certificate expires: $EXPIRY"
    
    # Check certificate validity
    if openssl x509 -in "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" -checkend 86400 > /dev/null; then
        success "Certificate is valid for at least 24 hours"
    else
        warning "Certificate expires within 24 hours"
    fi
else
    error "SSL certificate not found"
fi

# Check nginx status
log "Checking nginx status..."
if systemctl is-active --quiet nginx; then
    success "Nginx is running"
    
    # Check nginx configuration
    if nginx -t 2>/dev/null; then
        success "Nginx configuration is valid"
    else
        error "Nginx configuration has errors"
    fi
else
    error "Nginx is not running"
fi

# Check fail2ban status
log "Checking fail2ban status..."
if systemctl is-active --quiet fail2ban; then
    success "Fail2ban is running"
    
    # Check fail2ban jails
    JAILS=$(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr -d ' ')
    if [ -n "$JAILS" ]; then
        success "Active jails: $JAILS"
    else
        warning "No active fail2ban jails"
    fi
else
    error "Fail2ban is not running"
fi

# Check SSH service
log "Checking SSH service..."
if systemctl is-active --quiet sshd; then
    success "SSH service (sshd) is running"
elif systemctl is-active --quiet ssh; then
    success "SSH service (ssh) is running"
else
    error "SSH service is not running"
fi

# Check firewall status
log "Checking firewall status..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        success "UFW firewall is active"
        
        # Check important ports
        if ufw status | grep -q "22/tcp"; then
            success "SSH port 22 is allowed"
        else
            warning "SSH port 22 is not explicitly allowed"
        fi
        
        if ufw status | grep -q "80/tcp"; then
            success "HTTP port 80 is allowed"
        else
            warning "HTTP port 80 is not allowed"
        fi
        
        if ufw status | grep -q "443/tcp"; then
            success "HTTPS port 443 is allowed"
        else
            warning "HTTPS port 443 is not allowed"
        fi
    else
        warning "UFW firewall is not active"
    fi
else
    info "UFW not installed"
fi

# Check n8n service
log "Checking n8n service..."
if systemctl is-active --quiet n8n; then
    success "n8n service is running"
elif docker ps | grep -q n8n; then
    success "n8n is running in Docker"
else
    warning "n8n service status unclear"
fi

# Check log rotation
log "Checking log rotation..."
if [ -f "/etc/logrotate.d/n8n" ]; then
    success "Log rotation is configured"
else
    warning "Log rotation not configured"
fi

# Check HTTPS accessibility
log "Checking HTTPS accessibility..."
if curl -s --max-time 10 "https://$DOMAIN_NAME" > /dev/null 2>&1; then
    success "HTTPS is accessible"
else
    warning "HTTPS is not accessible (this might be normal if n8n is still starting)"
fi

# Check HTTP redirect
log "Checking HTTP redirect..."
if curl -s --max-time 10 -I "http://$DOMAIN_NAME" | grep -q "301"; then
    success "HTTP redirects to HTTPS"
else
    warning "HTTP redirect not working properly"
fi

log "Security status check complete!"
info "If you see any errors or warnings, review the secure-server.sh script output"
info "Access your n8n instance at: https://$DOMAIN_NAME"
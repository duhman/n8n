#!/bin/bash

# Security Hardening Script for n8n Server
# This script implements additional security measures

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

log "Starting security hardening..."

# Get domain name
if [ -f "/opt/n8n/deployment-info.txt" ]; then
    DOMAIN_NAME=$(grep "Domain:" /opt/n8n/deployment-info.txt | cut -d' ' -f2)
else
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
fi

# Create temporary HTTP-only nginx configuration for SSL certificate generation
log "Creating temporary HTTP-only nginx configuration..."
cat > /etc/nginx/sites-available/n8n << EOF
# Temporary HTTP-only configuration for Let's Encrypt
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    
    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Proxy to n8n for initial setup
    location / {
        proxy_pass http://localhost:5678;
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

# Test and reload nginx with temporary config
nginx -t && systemctl reload nginx

# Create certbot directory
mkdir -p /var/www/certbot

# SSL Certificate Setup
log "Setting up SSL certificate with Let's Encrypt..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    log "Generating SSL certificate for $DOMAIN_NAME..."
    if certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --redirect; then
        log "SSL certificate generated successfully!"
    else
        error "Failed to generate SSL certificate. Please check that:"
        error "1. Domain $DOMAIN_NAME points to this server's IP address"
        error "2. Port 80 is open and accessible from the internet"
        error "3. No other web server is running on port 80"
        error "You can check DNS with: nslookup $DOMAIN_NAME"
    fi
else
    log "SSL certificate already exists for $DOMAIN_NAME"
fi

# Enhanced Nginx security configuration
log "Enhancing Nginx security configuration..."
cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
# SSL Protocol and Ciphers
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;
ssl_prefer_server_ciphers on;

# SSL Session Settings
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# OCSP Stapling (only if certificate supports it)
# ssl_stapling on;
# ssl_stapling_verify on;
# resolver 8.8.8.8 8.8.4.4 valid=300s;
# resolver_timeout 5s;

# Disable preloading HSTS for now
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains";
EOF

# Verify SSL certificate exists before creating full configuration
if [ ! -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    error "SSL certificate not found. Cannot proceed with HTTPS configuration."
fi

# Update Nginx configuration with enhanced security
log "Creating full nginx configuration with SSL..."
cat > /etc/nginx/sites-available/n8n << EOF
# Rate limiting (relaxed for multi-user environments)
limit_req_zone \$binary_remote_addr zone=n8n_limit:10m rate=30r/s;
limit_conn_zone \$binary_remote_addr zone=n8n_conn:10m;

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
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline' 'unsafe-eval';" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    
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

# Reload Nginx
nginx -t && systemctl reload nginx

# Configure advanced fail2ban rules
log "Configuring advanced fail2ban rules..."
cat > /etc/fail2ban/filter.d/n8n-auth.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"POST /rest/login.*" 401
            ^<HOST>.*"POST /rest/login.*" 403
ignoreregex =
EOF

cat > /etc/fail2ban/jail.d/n8n.conf << EOF
[n8n-auth]
enabled = true
port = http,https
filter = n8n-auth
logpath = /var/log/nginx/n8n_access.log
maxretry = 8
bantime = 1800
findtime = 600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/*error.log
maxretry = 10
bantime = 600
findtime = 60
EOF

systemctl restart fail2ban

# SSH Hardening
log "Hardening SSH configuration..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Update SSH configuration
cat >> /etc/ssh/sshd_config.d/99-n8n-hardening.conf << 'EOF'
# Disable root login
PermitRootLogin no

# Disable password authentication
PasswordAuthentication no
PubkeyAuthentication yes

# Limit authentication attempts
MaxAuthTries 3
MaxSessions 5

# Disable empty passwords
PermitEmptyPasswords no

# Login grace time
LoginGraceTime 20

# Disable X11 forwarding
X11Forwarding no

# Use strong ciphers
Ciphers chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

# Client alive settings
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Restart SSH service
# Restart SSH service (try both common service names)
if systemctl is-active --quiet sshd; then
    systemctl restart sshd
elif systemctl is-active --quiet ssh; then
    systemctl restart ssh
else
    log "SSH service not found or not running"
fi

# Set up log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/n8n << EOF
/var/log/nginx/n8n_*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 \$(cat /var/run/nginx.pid)
        fi
    endscript
}
EOF

# Install and configure auditd
log "Installing and configuring auditd..."
apt-get install -y auditd audispd-plugins

# Configure audit rules
cat > /etc/audit/rules.d/n8n.rules << 'EOF'
# Monitor n8n configuration changes
-w /opt/n8n/n8n-production/.env -p wa -k n8n_config
-w /opt/n8n/n8n-production/docker-compose.yml -p wa -k n8n_config

# Monitor authentication
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes

# Monitor Docker activities
-w /usr/bin/docker -p x -k docker_commands
-w /var/lib/docker -p wa -k docker_lib

# Monitor network connections
-a exit,always -F arch=b64 -S socket -S connect -k network_connections
EOF

systemctl enable auditd
systemctl restart auditd

# Set up automated certificate renewal
log "Setting up automated SSL certificate renewal..."
cat > /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
chmod +x /etc/cron.daily/certbot-renew

# Create security monitoring script
log "Creating security monitoring script..."
cat > /usr/local/bin/n8n-security-check.sh << 'EOF'
#!/bin/bash
# Security monitoring script for n8n

# Check for failed login attempts
echo "=== Failed Login Attempts (last 24h) ==="
grep "401\|403" /var/log/nginx/n8n_access.log | grep "/rest/login" | tail -20

# Check fail2ban status
echo -e "\n=== Fail2ban Status ==="
fail2ban-client status n8n-auth

# Check disk usage
echo -e "\n=== Disk Usage ==="
df -h | grep -E "^/|^Filesystem"

# Check Docker container status
echo -e "\n=== Docker Container Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check for suspicious processes
echo -e "\n=== High CPU Processes ==="
ps aux | sort -nrk 3,3 | head -5
EOF
chmod +x /usr/local/bin/n8n-security-check.sh

# Final security report
log "Security hardening complete!"
echo ""
echo "==================================="
echo "Security Configuration Summary:"
echo "==================================="
echo "✓ SSL/TLS configured with Let's Encrypt"
echo "✓ Nginx security headers enabled"
echo "✓ Rate limiting configured"
echo "✓ SSH hardened (key-only authentication)"
echo "✓ Fail2ban configured with n8n rules"
echo "✓ Audit logging enabled"
echo "✓ Log rotation configured"
echo "✓ Automated certificate renewal set up"
echo ""
echo "==================================="
echo "Security Recommendations:"
echo "==================================="
echo "1. Regularly update the system: apt update && apt upgrade"
echo "2. Monitor logs: tail -f /var/log/nginx/n8n_error.log"
echo "3. Check security status: /usr/local/bin/n8n-security-check.sh"
echo "4. Review fail2ban bans: fail2ban-client status"
echo "5. Keep n8n updated: cd /opt/n8n && git pull && docker compose pull"
echo ""
echo "==================================="
echo "Important Files:"
echo "==================================="
echo "Nginx config: /etc/nginx/sites-available/n8n"
echo "SSL params: /etc/nginx/snippets/ssl-params.conf"
echo "Fail2ban config: /etc/fail2ban/jail.d/n8n.conf"
echo "Audit rules: /etc/audit/rules.d/n8n.rules"
echo "Security check: /usr/local/bin/n8n-security-check.sh"
echo "==================================="

echo ""
echo "==================================="
echo "Multi-User Access Notes:"
echo "==================================="
echo "• Rate limiting set to 30 req/s with 50 burst allowance"
echo "• Fail2ban allows 8 login attempts before 30min ban"
echo "• Connection limit set to 25 concurrent per IP"
echo "• These settings balance security with usability"
echo "• Adjust in /etc/nginx/sites-available/n8n if needed"
echo "==================================="

log "Server security hardening completed!"
#!/bin/bash

# n8n Multi-User Setup Verification Script
# This script verifies that n8n is properly configured for multi-user access

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

success() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
}

# Variables
PRODUCTION_DIR="/opt/n8n/n8n-production"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

log "Starting n8n multi-user setup verification..."

echo ""
echo "==================================="
echo "n8n Multi-User Setup Verification"
echo "==================================="

# Load environment variables
if [ -f "$PRODUCTION_DIR/.env" ]; then
    export $(grep -v '^#' "$PRODUCTION_DIR/.env" | xargs)
else
    fail ".env file not found in $PRODUCTION_DIR"
    exit 1
fi

# Check 1: User Management
echo ""
info "1. Checking User Management Configuration..."
if [ "${N8N_USER_MANAGEMENT_DISABLED:-true}" = "false" ]; then
    success "User management is enabled"
else
    fail "User management is disabled"
    echo "   Fix: Set N8N_USER_MANAGEMENT_DISABLED=false in .env"
fi

# Check 2: Email Configuration
echo ""
info "2. Checking Email Configuration..."
if [ "${N8N_EMAIL_MODE:-}" = "smtp" ]; then
    success "SMTP email is configured"
    if [ -n "${N8N_SMTP_HOST:-}" ] && [ -n "${N8N_SMTP_USER:-}" ]; then
        success "SMTP credentials are set"
    else
        warning "SMTP credentials incomplete"
        echo "   Check: N8N_SMTP_HOST, N8N_SMTP_USER, N8N_SMTP_PASS"
    fi
else
    warning "Email is not configured"
    echo "   Impact: Users cannot be invited via email"
    echo "   Fix: Configure SMTP settings in .env"
fi

# Check 3: Docker Configuration
echo ""
info "3. Checking Docker Configuration..."
cd "$PRODUCTION_DIR"
if sudo -u n8n docker compose ps | grep -q "Up"; then
    success "n8n services are running"
    
    # Check n8n version
    version=$(sudo -u n8n docker compose exec -T n8n n8n --version 2>/dev/null || echo "unknown")
    if [[ "$version" == *"1.102.0"* ]]; then
        success "Running n8n 1.102.0 (latest)"
    else
        warning "Running n8n version: $version"
        echo "   Recommendation: Update to 1.102.0 with ./update-n8n.sh 1.102.0"
    fi
else
    fail "n8n services are not running"
    echo "   Fix: Run 'docker compose up -d' in $PRODUCTION_DIR"
fi

# Check 4: Database Connection
echo ""
info "4. Checking Database Connection..."
if sudo -u n8n docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n}" > /dev/null 2>&1; then
    success "PostgreSQL database is running"
else
    fail "Cannot connect to PostgreSQL database"
fi

# Check 5: Web Access
echo ""
info "5. Checking Web Access..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|302"; then
    success "n8n web interface is accessible on port 5678"
else
    fail "Cannot access n8n web interface"
    echo "   Check: Docker container status and firewall rules"
fi

# Check 6: SSL/HTTPS Configuration
echo ""
info "6. Checking SSL/HTTPS Configuration..."
if [ -n "${N8N_HOST:-}" ] && [ "${N8N_HOST}" != "localhost" ]; then
    if [ -d "/etc/letsencrypt/live/${N8N_HOST}" ]; then
        success "SSL certificate exists for ${N8N_HOST}"
        
        # Check if certificate is valid
        if openssl x509 -in "/etc/letsencrypt/live/${N8N_HOST}/fullchain.pem" -noout -checkend 86400 > /dev/null 2>&1; then
            success "SSL certificate is valid"
        else
            warning "SSL certificate expires soon"
            echo "   Action: Certificate will auto-renew or run 'certbot renew'"
        fi
    else
        warning "No SSL certificate found for ${N8N_HOST}"
        echo "   Fix: Run ./secure-server.sh to set up SSL"
    fi
else
    warning "N8N_HOST not configured or set to localhost"
    echo "   Impact: Cannot use HTTPS or webhooks"
fi

# Check 7: Performance Settings
echo ""
info "7. Checking Performance Settings..."
if [ "${N8N_METRICS:-false}" = "true" ]; then
    success "Metrics are enabled"
else
    warning "Metrics are disabled"
    echo "   Recommendation: Enable with N8N_METRICS=true"
fi

if [ "${N8N_RUNNERS_ENABLED:-false}" = "true" ]; then
    success "Task runners are enabled"
else
    warning "Task runners are disabled"
    echo "   Recommendation: Enable with N8N_RUNNERS_ENABLED=true"
fi

# Check 8: Community Features
echo ""
info "8. Checking Community Features..."
if [ "${N8N_COMMUNITY_PACKAGES_ENABLED:-false}" = "true" ]; then
    success "Community packages are enabled"
else
    warning "Community packages are disabled"
    echo "   Recommendation: Enable with N8N_COMMUNITY_PACKAGES_ENABLED=true"
fi

# Check 9: Security Configuration
echo ""
info "9. Checking Security Configuration..."
if systemctl is-active --quiet fail2ban; then
    success "Fail2ban is running"
else
    warning "Fail2ban is not running"
    echo "   Fix: systemctl start fail2ban"
fi

if ufw status | grep -q "Status: active"; then
    success "UFW firewall is active"
else
    warning "UFW firewall is inactive"
    echo "   Fix: ufw enable"
fi

# Check 10: Backup Configuration
echo ""
info "10. Checking Backup Configuration..."
if [ -f "/usr/local/bin/n8n-backup.sh" ]; then
    success "Backup script is installed"
    
    if crontab -l 2>/dev/null | grep -q "n8n-backup"; then
        success "Automated backups are scheduled"
    else
        warning "Automated backups are not scheduled"
        echo "   Fix: Run ./backup-setup.sh"
    fi
else
    warning "Backup script not found"
    echo "   Fix: Run ./backup-setup.sh"
fi

# Summary
echo ""
echo "==================================="
echo "Verification Complete"
echo "==================================="

# Count successful checks
checks_passed=0
total_checks=10

# Recheck critical items for summary
[ "${N8N_USER_MANAGEMENT_DISABLED:-true}" = "false" ] && ((checks_passed++))
[ "${N8N_EMAIL_MODE:-}" = "smtp" ] && ((checks_passed++))
sudo -u n8n docker compose ps | grep -q "Up" && ((checks_passed++))
sudo -u n8n docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n}" > /dev/null 2>&1 && ((checks_passed++))
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|302" && ((checks_passed++))
[ -n "${N8N_HOST:-}" ] && [ "${N8N_HOST}" != "localhost" ] && [ -d "/etc/letsencrypt/live/${N8N_HOST}" ] && ((checks_passed++))
[ "${N8N_METRICS:-false}" = "true" ] && ((checks_passed++))
[ "${N8N_COMMUNITY_PACKAGES_ENABLED:-false}" = "true" ] && ((checks_passed++))
systemctl is-active --quiet fail2ban && ((checks_passed++))
[ -f "/usr/local/bin/n8n-backup.sh" ] && ((checks_passed++))

if [ $checks_passed -ge 8 ]; then
    echo -e "${GREEN}✓ Multi-user setup is well configured ($checks_passed/$total_checks checks passed)${NC}"
elif [ $checks_passed -ge 6 ]; then
    echo -e "${YELLOW}⚠ Multi-user setup needs some improvements ($checks_passed/$total_checks checks passed)${NC}"
else
    echo -e "${RED}✗ Multi-user setup needs significant configuration ($checks_passed/$total_checks checks passed)${NC}"
fi

echo ""
echo "==================================="
echo "Next Steps for Multi-User Access:"
echo "==================================="
echo "1. Access n8n at: ${N8N_PROTOCOL:-http}://${N8N_HOST:-localhost}:${N8N_PORT:-5678}"
echo "2. Create your first admin user account"
echo "3. Configure SMTP if not already done (for user invitations)"
echo "4. Go to Settings > Users to invite additional users"
echo "5. Set up appropriate permissions and roles"
echo ""

if [ "${N8N_EMAIL_MODE:-}" != "smtp" ]; then
    echo "⚠ Without email configuration, you'll need to:"
    echo "   • Share login credentials manually"
    echo "   • Users cannot reset passwords via email"
    echo "   • No email notifications for workflow events"
    echo ""
fi

echo "==================================="
echo "Support Documentation:"
echo "==================================="
echo "• n8n User Management: https://docs.n8n.io/user-management/"
echo "• SMTP Configuration: https://docs.n8n.io/hosting/configuration/"
echo "• Troubleshooting: Check logs with 'docker compose logs -f'"
echo "==================================="

log "Verification completed!"
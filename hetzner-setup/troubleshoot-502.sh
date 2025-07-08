#!/bin/bash

# Troubleshoot 502 Bad Gateway Error
# This script diagnoses why n8n isn't accessible

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

log "Troubleshooting 502 Bad Gateway error..."
echo "======================================"

# Check if n8n container is running
log "Checking Docker containers..."
if docker ps | grep -q n8n; then
    success "n8n container is running"
    docker ps | grep n8n
else
    error "n8n container is NOT running"
    
    # Check if container exists but stopped
    if docker ps -a | grep -q n8n; then
        warning "n8n container exists but is stopped"
        info "Checking container logs..."
        docker logs n8n --tail 50
    fi
fi

# Check if n8n is listening on port 5678
log "Checking if n8n is listening on port 5678..."
if netstat -tuln | grep -q ":5678"; then
    success "Something is listening on port 5678"
else
    error "Nothing is listening on port 5678"
fi

# Test n8n directly
log "Testing n8n directly on localhost:5678..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200"; then
    success "n8n is responding on localhost:5678"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678)
    error "n8n returned HTTP code: $HTTP_CODE"
fi

# Check nginx configuration
log "Checking nginx configuration..."
if nginx -t 2>/dev/null; then
    success "Nginx configuration is valid"
else
    error "Nginx configuration has errors"
    nginx -t
fi

# Check nginx error logs
log "Recent nginx errors:"
tail -n 20 /var/log/nginx/error.log | grep -E "(error|crit|alert|emerg)" || echo "No critical errors found"

# Check Docker compose status
log "Checking Docker Compose status..."
cd /opt/n8n
if [ -f "docker-compose.yml" ]; then
    info "Docker Compose file found"
    docker compose ps
else
    error "Docker Compose file not found in /opt/n8n"
fi

# Check PostgreSQL
log "Checking PostgreSQL container..."
if docker ps | grep -q postgres; then
    success "PostgreSQL container is running"
    
    # Test database connection
    if docker exec postgres pg_isready -U n8n 2>/dev/null; then
        success "PostgreSQL is accepting connections"
    else
        error "PostgreSQL is not accepting connections"
    fi
else
    error "PostgreSQL container is NOT running"
fi

# Check environment file
log "Checking environment configuration..."
if [ -f "/opt/n8n/.env" ]; then
    success ".env file exists"
    # Check for required variables
    if grep -q "N8N_ENCRYPTION_KEY" /opt/n8n/.env; then
        success "Encryption key is set"
    else
        error "N8N_ENCRYPTION_KEY is missing"
    fi
else
    error ".env file not found in /opt/n8n"
fi

# Memory and disk check
log "System resources:"
free -h | grep -E "Mem:|Swap:"
df -h | grep -E "/$|/opt"

echo -e "\n${YELLOW}=== SUGGESTED FIXES ===${NC}"
echo "1. Start/restart n8n containers:"
echo "   cd /opt/n8n && docker compose down && docker compose up -d"
echo ""
echo "2. Check container logs:"
echo "   docker logs n8n --tail 100"
echo "   docker logs postgres --tail 100"
echo ""
echo "3. Verify .env file has all required variables:"
echo "   cat /opt/n8n/.env"
echo ""
echo "4. Restart nginx:"
echo "   systemctl restart nginx"
echo ""
echo "5. If database issues, check PostgreSQL:"
echo "   docker exec -it postgres psql -U n8n -d n8n"
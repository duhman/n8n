#!/bin/bash

# n8n Update Script for Hetzner Cloud
# This script safely updates n8n to a specified version with full backup

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
PRODUCTION_DIR="$N8N_DIR/n8n-production"
BACKUP_DIR="/opt/n8n-backups"
TARGET_VERSION="${1:-1.100.1}"  # Default to 1.100.1 if no version specified

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Function to get current n8n version
get_current_version() {
    cd "$PRODUCTION_DIR"
    local version=$(sudo -u n8n docker compose exec -T n8n n8n --version 2>/dev/null || echo "unknown")
    echo "$version"
}

# Function to create backup
create_backup() {
    local backup_name="n8n-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "Creating backup at $backup_path..."
    mkdir -p "$backup_path"
    
    # Backup database
    log "Backing up PostgreSQL database..."
    cd "$PRODUCTION_DIR"
    sudo -u n8n docker compose exec -T postgres pg_dump -U ${POSTGRES_USER:-n8n} ${POSTGRES_DB:-n8n} > "$backup_path/n8n_database.sql"
    
    # Backup n8n data directory
    log "Backing up n8n data directory..."
    cp -r "$PRODUCTION_DIR/data" "$backup_path/"
    
    # Backup .env file
    log "Backing up configuration..."
    cp "$PRODUCTION_DIR/.env" "$backup_path/"
    
    # Backup docker-compose.yml
    cp "$PRODUCTION_DIR/docker-compose.yml" "$backup_path/"
    
    # Create backup info
    cat > "$backup_path/backup-info.txt" << EOF
Backup Date: $(date)
n8n Version: $(get_current_version)
Target Update Version: $TARGET_VERSION
Server: $(hostname)
EOF
    
    # Compress backup
    log "Compressing backup..."
    cd "$BACKUP_DIR"
    tar -czf "$backup_name.tar.gz" "$backup_name"
    rm -rf "$backup_name"
    
    log "Backup completed: $backup_name.tar.gz"
    echo "$backup_name"
}

# Function to update n8n
update_n8n() {
    log "Updating n8n to version $TARGET_VERSION..."
    
    cd "$PRODUCTION_DIR"
    
    # Update docker-compose.yml to use specific version
    log "Updating Docker Compose configuration..."
    sed -i.bak "s|image: docker.n8n.io/n8nio/n8n:.*|image: docker.n8n.io/n8nio/n8n:$TARGET_VERSION|" docker-compose.yml
    
    # Pull new image
    log "Pulling n8n version $TARGET_VERSION..."
    sudo -u n8n docker compose pull
    
    # Stop n8n gracefully
    log "Stopping n8n services..."
    sudo -u n8n docker compose stop n8n
    
    # Wait for graceful shutdown
    sleep 5
    
    # Start updated n8n
    log "Starting updated n8n..."
    sudo -u n8n docker compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 30
    
    # Check health
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz | grep -q "200"; then
            log "n8n is healthy and responding"
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done
    
    if [ $retries -eq 0 ]; then
        error "n8n health check failed after update"
    fi
}

# Function to verify update
verify_update() {
    log "Verifying update..."
    
    cd "$PRODUCTION_DIR"
    
    # Check if services are running
    if ! sudo -u n8n docker compose ps | grep -q "Up"; then
        error "n8n services are not running properly"
    fi
    
    # Get new version
    local new_version=$(get_current_version)
    log "Current n8n version: $new_version"
    
    # Check logs for errors
    log "Checking logs for errors..."
    if sudo -u n8n docker compose logs --tail=50 n8n | grep -i "error" | grep -v "No error"; then
        warning "Found errors in logs - please review"
    fi
    
    # Test API endpoint
    log "Testing API endpoint..."
    if curl -s http://localhost:5678/api/v1/info > /dev/null; then
        log "API endpoint is responding"
    else
        warning "API endpoint test failed"
    fi
}

# Main execution
log "Starting n8n update process..."

# Check if production directory exists
if [ ! -d "$PRODUCTION_DIR" ]; then
    error "n8n production directory not found at $PRODUCTION_DIR"
fi

# Load environment variables
if [ -f "$PRODUCTION_DIR/.env" ]; then
    export $(grep -v '^#' "$PRODUCTION_DIR/.env" | xargs)
else
    error ".env file not found in $PRODUCTION_DIR"
fi

# Display current status
info "Current n8n version: $(get_current_version)"
info "Target version: $TARGET_VERSION"
echo ""
read -p "Do you want to proceed with the update? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Update cancelled by user"
    exit 0
fi

# Create backup
log "Creating backup before update..."
BACKUP_NAME=$(create_backup)

# Perform update
update_n8n

# Verify update
verify_update

# Update systemd service (if needed)
log "Reloading systemd configuration..."
systemctl daemon-reload

# Final status
log "Update completed successfully!"
echo ""
echo "==================================="
echo "Update Summary:"
echo "==================================="
echo "Previous version: $(cat "$BACKUP_DIR/$BACKUP_NAME/backup-info.txt" | grep "n8n Version" | cut -d: -f2)"
echo "Current version: $(get_current_version)"
echo "Backup location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo ""
echo "Services status:"
sudo -u n8n docker compose ps
echo ""
echo "==================================="
echo "Post-Update Actions:"
echo "==================================="
echo "1. Test your workflows to ensure they work correctly"
echo "2. Check the release notes for any breaking changes"
echo "3. Monitor logs: docker compose logs -f n8n"
echo ""
echo "If you encounter issues, restore from backup:"
echo "  $N8N_DIR/hetzner-setup/restore-from-backup.sh $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "==================================="

# Save update log
cat >> "$N8N_DIR/update-history.log" << EOF
Update Date: $(date)
From Version: $(cat "$BACKUP_DIR/$BACKUP_NAME/backup-info.txt" | grep "n8n Version" | cut -d: -f2)
To Version: $(get_current_version)
Backup: $BACKUP_DIR/$BACKUP_NAME.tar.gz
Status: Success
EOF

log "Update process completed!"
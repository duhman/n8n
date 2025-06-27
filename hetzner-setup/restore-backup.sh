#!/bin/bash

# n8n Backup Restoration Script
# Restores n8n from a backup file

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

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz> [--force]"
    echo ""
    echo "Available backups:"
    ls -lh /opt/n8n/backups/*.tar.gz 2>/dev/null || echo "No local backups found"
    exit 1
fi

BACKUP_FILE="$1"
FORCE_RESTORE="${2:-}"
PRODUCTION_DIR="/opt/n8n/n8n-production"
RESTORE_DIR="/tmp/n8n_restore_$$"

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
fi

log "n8n Backup Restoration Script"
log "Backup file: $BACKUP_FILE"

# Show backup information
log "Extracting backup information..."
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR" --wildcards "*/backup_info.txt" 2>/dev/null || true

if [ -f "$RESTORE_DIR"/*/backup_info.txt ]; then
    echo ""
    echo "==================================="
    echo "Backup Information:"
    echo "==================================="
    cat "$RESTORE_DIR"/*/backup_info.txt
    echo "==================================="
    echo ""
fi

# Confirmation
if [ "$FORCE_RESTORE" != "--force" ]; then
    warning "This will restore n8n from the backup and OVERWRITE current data!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log "Restoration cancelled"
        exit 0
    fi
fi

# Create restoration backup
log "Creating backup of current state..."
SAFETY_BACKUP="/opt/n8n/backups/pre_restore_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
cd "$PRODUCTION_DIR"
tar -czf "$SAFETY_BACKUP" data/ .env docker-compose.yml 2>/dev/null || true
log "Safety backup created: $SAFETY_BACKUP"

# Extract full backup
log "Extracting backup archive..."
rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Find the backup directory
BACKUP_DIR=$(find "$RESTORE_DIR" -name "n8n_backup_*" -type d | head -1)
if [ -z "$BACKUP_DIR" ]; then
    error "Invalid backup format"
fi

# Stop n8n services
log "Stopping n8n services..."
cd "$PRODUCTION_DIR"
docker compose down

# Restore PostgreSQL database
log "Restoring PostgreSQL database..."
if [ -f "$BACKUP_DIR/postgres_backup.sql" ]; then
    # Start only PostgreSQL
    docker compose up -d postgres
    
    # Wait for PostgreSQL to be ready
    log "Waiting for PostgreSQL to start..."
    sleep 10
    
    # Drop and recreate database
    docker compose exec -T postgres psql -U n8n -c "DROP DATABASE IF EXISTS n8n;"
    docker compose exec -T postgres psql -U n8n -c "CREATE DATABASE n8n;"
    
    # Restore database
    docker compose exec -T postgres psql -U n8n n8n < "$BACKUP_DIR/postgres_backup.sql"
    
    log "Database restored successfully"
else
    warning "No database backup found in archive"
fi

# Restore n8n data
log "Restoring n8n data..."
if [ -f "$BACKUP_DIR/n8n_data.tar.gz" ]; then
    # Backup current data
    if [ -d "$PRODUCTION_DIR/data/n8n" ]; then
        mv "$PRODUCTION_DIR/data/n8n" "$PRODUCTION_DIR/data/n8n.old.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Extract n8n data
    tar -xzf "$BACKUP_DIR/n8n_data.tar.gz" -C "$PRODUCTION_DIR/data/"
    
    # Fix permissions
    chown -R n8n:n8n "$PRODUCTION_DIR/data/n8n"
    
    log "n8n data restored successfully"
else
    warning "No n8n data backup found in archive"
fi

# Restore configuration
if [ -f "$BACKUP_DIR/env.enc" ]; then
    read -p "Restore environment configuration? (y/n): " RESTORE_ENV
    if [[ "$RESTORE_ENV" =~ ^[Yy]$ ]]; then
        # Backup current .env
        cp "$PRODUCTION_DIR/.env" "$PRODUCTION_DIR/.env.pre_restore"
        
        # Decrypt and restore .env
        log "Enter the encryption password (hostname-date format):"
        openssl enc -aes-256-cbc -d -in "$BACKUP_DIR/env.enc" -out "$PRODUCTION_DIR/.env" -pbkdf2
        
        # Fix permissions
        chown n8n:n8n "$PRODUCTION_DIR/.env"
        chmod 600 "$PRODUCTION_DIR/.env"
        
        log "Configuration restored (old config backed up as .env.pre_restore)"
    fi
fi

# Restore docker-compose.yml if exists
if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
    cp "$PRODUCTION_DIR/docker-compose.yml" "$PRODUCTION_DIR/docker-compose.yml.pre_restore"
    cp "$BACKUP_DIR/docker-compose.yml" "$PRODUCTION_DIR/docker-compose.yml"
    log "docker-compose.yml restored (old version backed up)"
fi

# Clean up temporary files
rm -rf "$RESTORE_DIR"

# Start n8n services
log "Starting n8n services..."
cd "$PRODUCTION_DIR"
docker compose up -d

# Wait for services to start
log "Waiting for services to start..."
sleep 15

# Check service status
if docker compose ps | grep -q "Up"; then
    log "n8n services started successfully!"
else
    error "Failed to start n8n services. Check logs with: docker compose logs"
fi

# Verify restoration
log "Verifying restoration..."
echo ""
echo "==================================="
echo "Restoration Summary:"
echo "==================================="
echo "✓ Backup restored from: $BACKUP_FILE"
echo "✓ Safety backup created: $SAFETY_BACKUP"
echo "✓ Services restarted"
echo ""
echo "Service Status:"
docker compose ps
echo ""
echo "==================================="
echo "Post-Restoration Steps:"
echo "==================================="
echo "1. Verify n8n is accessible at your URL"
echo "2. Check workflows are intact"
echo "3. Test webhook functionality"
echo "4. Monitor logs: docker compose logs -f"
echo ""
echo "If issues occur, restore from safety backup:"
echo "  $0 $SAFETY_BACKUP --force"
echo "==================================="

log "Restoration completed successfully!"

# Create restoration log
RESTORE_LOG="/var/log/n8n/restore.log"
cat >> "$RESTORE_LOG" << EOF
[$(date)] Restored from: $BACKUP_FILE
[$(date)] Safety backup: $SAFETY_BACKUP
[$(date)] Restoration completed by: $(whoami)
EOF
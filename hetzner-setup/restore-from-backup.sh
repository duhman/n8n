#!/bin/bash

# n8n Restore Script for Hetzner Cloud
# This script restores n8n from a backup

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
BACKUP_FILE="${1:-}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Check if backup file provided
if [ -z "$BACKUP_FILE" ]; then
    error "Usage: $0 <backup-file.tar.gz>"
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
fi

log "Starting n8n restore process..."

# Extract backup
TEMP_DIR="/tmp/n8n-restore-$(date +%Y%m%d_%H%M%S)"
log "Extracting backup to $TEMP_DIR..."
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find extracted directory
BACKUP_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "n8n-backup-*" | head -n1)
if [ -z "$BACKUP_DIR" ]; then
    error "Could not find backup directory in archive"
fi

# Display backup info
log "Backup information:"
cat "$BACKUP_DIR/backup-info.txt"
echo ""

# Confirm restoration
read -p "Do you want to restore from this backup? This will stop n8n and replace current data! (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Restore cancelled by user"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Stop n8n services
log "Stopping n8n services..."
cd "$PRODUCTION_DIR"
sudo -u n8n docker compose down

# Backup current state (just in case)
log "Creating safety backup of current state..."
SAFETY_BACKUP="/opt/n8n-backups/pre-restore-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SAFETY_BACKUP"
cp -r "$PRODUCTION_DIR/data" "$SAFETY_BACKUP/"
cp "$PRODUCTION_DIR/.env" "$SAFETY_BACKUP/" 2>/dev/null || true
cp "$PRODUCTION_DIR/docker-compose.yml" "$SAFETY_BACKUP/" 2>/dev/null || true

# Restore files
log "Restoring configuration files..."
cp "$BACKUP_DIR/.env" "$PRODUCTION_DIR/"
cp "$BACKUP_DIR/docker-compose.yml" "$PRODUCTION_DIR/"

# Clear existing data
log "Clearing existing data..."
rm -rf "$PRODUCTION_DIR/data"

# Restore data directory
log "Restoring data directory..."
cp -r "$BACKUP_DIR/data" "$PRODUCTION_DIR/"

# Set proper permissions
chown -R n8n:n8n "$PRODUCTION_DIR/data"
chown n8n:n8n "$PRODUCTION_DIR/.env"
chmod 600 "$PRODUCTION_DIR/.env"

# Start services
log "Starting n8n services..."
cd "$PRODUCTION_DIR"
sudo -u n8n docker compose up -d

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
sleep 10

# Load environment variables
export $(grep -v '^#' "$PRODUCTION_DIR/.env" | xargs)

# Restore database
log "Restoring PostgreSQL database..."
sudo -u n8n docker compose exec -T postgres psql -U ${POSTGRES_USER:-n8n} -c "DROP DATABASE IF EXISTS ${POSTGRES_DB:-n8n};"
sudo -u n8n docker compose exec -T postgres psql -U ${POSTGRES_USER:-n8n} -c "CREATE DATABASE ${POSTGRES_DB:-n8n};"
sudo -u n8n docker compose exec -T postgres psql -U ${POSTGRES_USER:-n8n} ${POSTGRES_DB:-n8n} < "$BACKUP_DIR/n8n_database.sql"

# Restart n8n to ensure it connects to restored database
log "Restarting n8n..."
sudo -u n8n docker compose restart n8n

# Wait for services
log "Waiting for services to be ready..."
sleep 30

# Verify restoration
log "Verifying restoration..."
if sudo -u n8n docker compose ps | grep -q "Up"; then
    log "Services are running"
else
    error "Services failed to start after restoration"
fi

# Check health
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz | grep -q "200"; then
    log "n8n is healthy and responding"
else
    warning "n8n health check failed - please check logs"
fi

# Clean up
log "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Final status
log "Restore completed successfully!"
echo ""
echo "==================================="
echo "Restore Summary:"
echo "==================================="
echo "Restored from: $BACKUP_FILE"
echo "Safety backup: $SAFETY_BACKUP"
echo ""
echo "Services status:"
sudo -u n8n docker compose ps
echo ""
echo "==================================="
echo "Post-Restore Actions:"
echo "==================================="
echo "1. Verify your workflows are working correctly"
echo "2. Check credentials are intact"
echo "3. Monitor logs: docker compose logs -f n8n"
echo ""
echo "If restore failed, you can find pre-restore data at:"
echo "  $SAFETY_BACKUP"
echo "==================================="

# Log restoration
cat >> "$N8N_DIR/restore-history.log" << EOF
Restore Date: $(date)
Restored From: $BACKUP_FILE
Safety Backup: $SAFETY_BACKUP
Status: Success
EOF

log "Restore process completed!"
#!/bin/bash

# n8n Automated Backup Setup Script
# Configures automated backups to Hetzner Storage Box or local storage

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

# Variables
BACKUP_DIR="/opt/n8n/backups"
PRODUCTION_DIR="/opt/n8n/n8n-production"
BACKUP_SCRIPT="/usr/local/bin/n8n-backup.sh"
BACKUP_LOG="/var/log/n8n/backup.log"

log "Setting up automated backups for n8n..."

# Create backup directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$BACKUP_LOG")"
chown -R n8n:n8n "$BACKUP_DIR"
chown -R n8n:n8n "$(dirname "$BACKUP_LOG")"

# Ask for backup configuration
echo ""
echo "Choose backup destination:"
echo "1) Local storage only"
echo "2) Hetzner Storage Box (recommended)"
echo "3) Custom remote location (rsync/SSH)"
read -p "Enter choice (1-3): " BACKUP_CHOICE

# Configure based on choice
case $BACKUP_CHOICE in
    2)
        read -p "Enter Storage Box username (e.g., u123456): " STORAGE_USER
        read -p "Enter Storage Box hostname (e.g., u123456.your-storagebox.de): " STORAGE_HOST
        read -p "Enter Storage Box path (e.g., /backups/n8n): " STORAGE_PATH
        
        # Test SSH connection
        log "Testing Storage Box connection..."
        if ! sudo -u n8n ssh -o ConnectTimeout=10 -o BatchMode=yes "${STORAGE_USER}@${STORAGE_HOST}" "echo 'Connection successful'" 2>/dev/null; then
            warning "SSH key authentication not set up. Setting up now..."
            
            # Generate SSH key if not exists
            if [ ! -f /home/n8n/.ssh/id_ed25519 ]; then
                sudo -u n8n ssh-keygen -t ed25519 -f /home/n8n/.ssh/id_ed25519 -N ""
            fi
            
            echo ""
            echo "Please add this SSH key to your Storage Box:"
            echo "======================================="
            cat /home/n8n/.ssh/id_ed25519.pub
            echo "======================================="
            echo ""
            echo "Instructions:"
            echo "1. Login to Hetzner Robot"
            echo "2. Go to Storage Box settings"
            echo "3. Add the above SSH key"
            echo "4. Wait 5 minutes for propagation"
            echo ""
            read -p "Press Enter after adding the SSH key..."
        fi
        
        BACKUP_TYPE="storage_box"
        ;;
    3)
        read -p "Enter remote username: " REMOTE_USER
        read -p "Enter remote hostname: " REMOTE_HOST
        read -p "Enter remote path: " REMOTE_PATH
        BACKUP_TYPE="remote"
        ;;
    *)
        BACKUP_TYPE="local"
        ;;
esac

# Create main backup script
log "Creating backup script..."
cat > "$BACKUP_SCRIPT" << 'EOF'
#!/bin/bash

# n8n Backup Script
set -euo pipefail

# Variables
BACKUP_DIR="/opt/n8n/backups"
PRODUCTION_DIR="/opt/n8n/n8n-production"
LOG_FILE="/var/log/n8n/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_backup_${DATE}"
TEMP_DIR="${BACKUP_DIR}/${BACKUP_NAME}"

# Logging function
log_backup() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup
log_backup "Starting n8n backup..."

# Create temporary backup directory
mkdir -p "$TEMP_DIR"

# Stop n8n to ensure data consistency (optional - comment out for live backups)
# log_backup "Stopping n8n services..."
# cd "$PRODUCTION_DIR"
# docker compose stop

# Backup PostgreSQL database
log_backup "Backing up PostgreSQL database..."
cd "$PRODUCTION_DIR"
docker compose exec -T postgres pg_dump -U n8n n8n > "${TEMP_DIR}/postgres_backup.sql"

# Backup n8n data directory
log_backup "Backing up n8n data..."
tar -czf "${TEMP_DIR}/n8n_data.tar.gz" -C "${PRODUCTION_DIR}/data" n8n/

# Backup environment file (encrypted)
log_backup "Backing up configuration..."
openssl enc -aes-256-cbc -salt -in "${PRODUCTION_DIR}/.env" -out "${TEMP_DIR}/env.enc" -k "$(hostname)-$(date +%Y%m%d)" -pbkdf2

# Backup docker-compose.yml
cp "${PRODUCTION_DIR}/docker-compose.yml" "${TEMP_DIR}/"

# Create backup info file
cat > "${TEMP_DIR}/backup_info.txt" << INFO
Backup Date: $(date)
Server: $(hostname)
n8n Version: $(docker compose exec -T n8n n8n --version 2>/dev/null || echo "unknown")
PostgreSQL Version: $(docker compose exec -T postgres psql --version 2>/dev/null || echo "unknown")
Backup Type: Full
INFO

# Start n8n again (if stopped)
# log_backup "Starting n8n services..."
# docker compose start

# Create compressed archive
log_backup "Creating backup archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME/"
rm -rf "$TEMP_DIR"

# Calculate backup size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
log_backup "Backup created: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

EOF

# Add backup type specific code
case $BACKUP_TYPE in
    "storage_box")
        cat >> "$BACKUP_SCRIPT" << EOF

# Upload to Hetzner Storage Box
log_backup "Uploading to Storage Box..."
if rsync -avz --progress "${BACKUP_NAME}.tar.gz" "${STORAGE_USER}@${STORAGE_HOST}:${STORAGE_PATH}/" >> "\$LOG_FILE" 2>&1; then
    log_backup "Upload successful"
    # Remove local backup after successful upload
    rm -f "${BACKUP_NAME}.tar.gz"
else
    log_backup "ERROR: Upload failed"
    exit 1
fi

# Clean up old backups on Storage Box (keep last 7 days)
log_backup "Cleaning up old backups..."
ssh "${STORAGE_USER}@${STORAGE_HOST}" "cd ${STORAGE_PATH} && ls -t n8n_backup_*.tar.gz | tail -n +8 | xargs -r rm -f"

EOF
        ;;
    "remote")
        cat >> "$BACKUP_SCRIPT" << EOF

# Upload to remote server
log_backup "Uploading to remote server..."
if rsync -avz --progress "${BACKUP_NAME}.tar.gz" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" >> "\$LOG_FILE" 2>&1; then
    log_backup "Upload successful"
    # Remove local backup after successful upload
    rm -f "${BACKUP_NAME}.tar.gz"
else
    log_backup "ERROR: Upload failed"
    exit 1
fi

# Clean up old backups on remote (keep last 7 days)
log_backup "Cleaning up old backups..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_PATH} && ls -t n8n_backup_*.tar.gz | tail -n +8 | xargs -r rm -f"

EOF
        ;;
    "local")
        cat >> "$BACKUP_SCRIPT" << 'EOF'

# Clean up old local backups (keep last 7 days)
log_backup "Cleaning up old backups..."
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime +7 -delete

EOF
        ;;
esac

# Complete the backup script
cat >> "$BACKUP_SCRIPT" << 'EOF'

# Log completion
log_backup "Backup completed successfully"

# Send notification (optional - configure email/webhook)
# echo "n8n backup completed: ${BACKUP_NAME}" | mail -s "n8n Backup Success" admin@example.com

exit 0
EOF

# Make script executable
chmod +x "$BACKUP_SCRIPT"
chown n8n:n8n "$BACKUP_SCRIPT"

# Create cron job for automated backups
log "Setting up automated backup schedule..."
cat > /etc/cron.d/n8n-backup << EOF
# n8n Automated Backup
# Run daily at 2:30 AM
30 2 * * * n8n $BACKUP_SCRIPT >> $BACKUP_LOG 2>&1
EOF

# Create backup monitoring script
log "Creating backup monitoring script..."
cat > /usr/local/bin/n8n-backup-status.sh << 'EOF'
#!/bin/bash

echo "==================================="
echo "n8n Backup Status"
echo "==================================="
echo ""

# Show last 5 backup log entries
echo "Recent Backup Activity:"
echo "-----------------------"
tail -n 20 /var/log/n8n/backup.log | grep -E "Starting|completed|ERROR" | tail -5

echo ""
echo "Backup Storage:"
echo "-----------------------"
if [ -d "/opt/n8n/backups" ]; then
    echo "Local backups:"
    ls -lh /opt/n8n/backups/*.tar.gz 2>/dev/null | tail -5 || echo "No local backups found"
    echo ""
    echo "Total size: $(du -sh /opt/n8n/backups 2>/dev/null | cut -f1)"
fi

echo ""
echo "Next scheduled backup:"
echo "-----------------------"
grep "n8n-backup" /etc/cron.d/n8n-backup

echo ""
echo "==================================="
EOF

chmod +x /usr/local/bin/n8n-backup-status.sh

# Test backup
read -p "Do you want to run a test backup now? (y/n): " RUN_TEST
if [[ "$RUN_TEST" =~ ^[Yy]$ ]]; then
    log "Running test backup..."
    sudo -u n8n "$BACKUP_SCRIPT"
fi

# Create backup documentation
cat > "${BACKUP_DIR}/README.md" << EOF
# n8n Backup Configuration

## Backup Schedule
- Automated backups run daily at 2:30 AM
- Backups are retained for 7 days

## Backup Contents
- PostgreSQL database dump
- n8n data directory (workflows, credentials, etc.)
- Configuration files (encrypted)
- Docker Compose configuration

## Backup Locations
- Local directory: ${BACKUP_DIR}
$([ "$BACKUP_TYPE" = "storage_box" ] && echo "- Storage Box: ${STORAGE_USER}@${STORAGE_HOST}:${STORAGE_PATH}")
$([ "$BACKUP_TYPE" = "remote" ] && echo "- Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}")

## Manual Backup
Run: sudo -u n8n ${BACKUP_SCRIPT}

## Check Backup Status
Run: ${BACKUP_DIR}/n8n-backup-status.sh

## Restore from Backup
Use: ${BACKUP_DIR}/restore-backup.sh <backup_file>

## Logs
Backup logs: ${BACKUP_LOG}
EOF

# Display summary
log "Backup setup complete!"
echo ""
echo "==================================="
echo "Backup Configuration Summary:"
echo "==================================="
echo "✓ Backup script: $BACKUP_SCRIPT"
echo "✓ Backup directory: $BACKUP_DIR"
echo "✓ Backup schedule: Daily at 2:30 AM"
echo "✓ Retention: 7 days"
echo "✓ Backup type: $BACKUP_TYPE"
echo ""
echo "Useful commands:"
echo "- Run backup: sudo -u n8n $BACKUP_SCRIPT"
echo "- Check status: /usr/local/bin/n8n-backup-status.sh"
echo "- View logs: tail -f $BACKUP_LOG"
echo "==================================="

log "Automated backup setup completed!"
#!/bin/bash

# n8n Production Backup Script
# This script backs up both PostgreSQL database and n8n data directory

set -e

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PREFIX="n8n_backup_${TIMESTAMP}"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found!"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo "Starting n8n backup process..."

# 1. Backup PostgreSQL database
echo "Backing up PostgreSQL database..."
docker-compose exec -T postgres pg_dump \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --no-owner \
    --no-privileges \
    --verbose \
    > "${BACKUP_DIR}/${BACKUP_PREFIX}_postgres.sql"

# Compress the database backup
gzip "${BACKUP_DIR}/${BACKUP_PREFIX}_postgres.sql"
echo "Database backup completed: ${BACKUP_PREFIX}_postgres.sql.gz"

# 2. Backup n8n data directory (excluding executions data to save space)
echo "Backing up n8n data directory..."
tar -czf "${BACKUP_DIR}/${BACKUP_PREFIX}_n8n_data.tar.gz" \
    --exclude='./data/n8n/n8n.log' \
    --exclude='./data/n8n/.n8n/nodes' \
    --exclude='./data/n8n/.n8n/packages' \
    ./data/n8n

echo "n8n data backup completed: ${BACKUP_PREFIX}_n8n_data.tar.gz"

# 3. Create a combined archive
echo "Creating combined backup archive..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_PREFIX}_complete.tar.gz" \
    "${BACKUP_PREFIX}_postgres.sql.gz" \
    "${BACKUP_PREFIX}_n8n_data.tar.gz"

# Remove individual files after creating combined archive
rm -f "${BACKUP_PREFIX}_postgres.sql.gz" "${BACKUP_PREFIX}_n8n_data.tar.gz"
cd ..

# 4. Cleanup old backups (keep only last 7 days)
echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "n8n_backup_*.tar.gz" -mtime +7 -delete

# 5. Display backup information
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_PREFIX}_complete.tar.gz" | cut -f1)
echo ""
echo "Backup completed successfully!"
echo "Backup file: ${BACKUP_DIR}/${BACKUP_PREFIX}_complete.tar.gz"
echo "Backup size: ${BACKUP_SIZE}"
echo ""

# Optional: Upload to cloud storage (uncomment and configure as needed)
# echo "Uploading to cloud storage..."
# aws s3 cp "${BACKUP_DIR}/${BACKUP_PREFIX}_complete.tar.gz" s3://your-bucket/n8n-backups/
# gsutil cp "${BACKUP_DIR}/${BACKUP_PREFIX}_complete.tar.gz" gs://your-bucket/n8n-backups/
# az storage blob upload --file "${BACKUP_DIR}/${BACKUP_PREFIX}_complete.tar.gz" --container-name backups

echo "All backup operations completed!"
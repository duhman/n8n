#!/bin/bash

# n8n Production Restore Script
# This script restores both PostgreSQL database and n8n data from backup

set -e

# Check if backup file is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./restore.sh <backup_file.tar.gz>"
    echo "Example: ./restore.sh backups/n8n_backup_20240101_120000_complete.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"
TEMP_DIR="./temp_restore_$$"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found!"
    exit 1
fi

echo "WARNING: This will restore n8n from backup and OVERWRITE existing data!"
echo "Backup file: $BACKUP_FILE"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Starting n8n restore process..."

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Extract backup archive
echo "Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the extracted files
POSTGRES_BACKUP=$(find "$TEMP_DIR" -name "*_postgres.sql.gz" | head -1)
N8N_DATA_BACKUP=$(find "$TEMP_DIR" -name "*_n8n_data.tar.gz" | head -1)

if [ -z "$POSTGRES_BACKUP" ] || [ -z "$N8N_DATA_BACKUP" ]; then
    echo "Error: Invalid backup archive structure!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Stop n8n service
echo "Stopping n8n services..."
docker-compose stop n8n

# 1. Restore PostgreSQL database
echo "Restoring PostgreSQL database..."
# Drop existing database and recreate
docker-compose exec -T postgres psql -U "${POSTGRES_USER}" -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
docker-compose exec -T postgres psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${POSTGRES_DB};"

# Restore database from backup
gunzip -c "$POSTGRES_BACKUP" | docker-compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
echo "Database restore completed!"

# 2. Restore n8n data directory
echo "Restoring n8n data directory..."
# Backup current data (just in case)
if [ -d "./data/n8n" ]; then
    mv ./data/n8n "./data/n8n_backup_$(date +%Y%m%d_%H%M%S)"
fi

# Extract n8n data
tar -xzf "$N8N_DATA_BACKUP" -C .
echo "n8n data restore completed!"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Start n8n service
echo "Starting n8n services..."
docker-compose start n8n

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service status
docker-compose ps

echo ""
echo "Restore completed successfully!"
echo "n8n should now be accessible at: http://localhost:${N8N_PORT}"
echo ""
echo "Note: A backup of the previous data was created in ./data/n8n_backup_*"
echo "You can remove it once you've verified the restore was successful."
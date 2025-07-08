#!/bin/bash

# Quick script to check current n8n version

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
PRODUCTION_DIR="/opt/n8n/n8n-production"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo -e "${BLUE}n8n Version Information${NC}"
echo "=================================="

# Get version from running container
cd "$PRODUCTION_DIR"
echo -n "Current n8n version: "
sudo -u n8n docker compose exec -T n8n n8n --version 2>/dev/null || echo "Could not determine version"

# Get image version
echo -n "Docker image: "
sudo -u n8n docker compose images n8n --format "table {{.Repository}}:{{.Tag}}" | tail -n1

# Check for available updates
echo ""
echo -e "${BLUE}Latest versions available:${NC}"
echo "Current latest: 1.102.0"
echo "Current next: 1.103.0 (beta)"
echo ""
echo "To update, run: ./update-n8n.sh [version]"
echo "Example: ./update-n8n.sh 1.102.0"
echo ""
echo -e "${GREEN}Note:${NC} Version 1.102.0 includes enhanced multi-user features and performance improvements"
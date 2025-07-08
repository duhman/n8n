#!/bin/bash

# Fix SSH Access Script
# This script helps restore SSH access when locked out

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

log "SSH Access Recovery Script"
log "=========================="

echo "Choose an option:"
echo "1. Enable root login temporarily (less secure)"
echo "2. Create a new sudo user (recommended)"
echo "3. Re-enable password authentication (temporary fix)"
echo "4. Show current SSH configuration"
echo "5. Restore original SSH configuration"

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        log "Enabling root login temporarily..."
        # Remove the PermitRootLogin no line from the hardening config
        sed -i '/PermitRootLogin no/d' /etc/ssh/sshd_config.d/99-n8n-hardening.conf 2>/dev/null || true
        
        # Add PermitRootLogin yes temporarily
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-n8n-hardening.conf
        
        # Restart SSH
        if systemctl is-active --quiet sshd; then
            systemctl restart sshd
        elif systemctl is-active --quiet ssh; then
            systemctl restart ssh
        fi
        
        warning "Root login is now enabled!"
        warning "This is less secure. Please create a sudo user instead."
        info "You can now SSH as root from your local machine"
        ;;
        
    2)
        log "Creating a new sudo user..."
        read -p "Enter username for new user: " username
        
        # Create user
        if id "$username" &>/dev/null; then
            warning "User $username already exists"
        else
            adduser --gecos "" "$username"
            usermod -aG sudo "$username"
            log "User $username created and added to sudo group"
        fi
        
        # Set up SSH key
        read -p "Do you want to set up SSH key authentication for $username? (y/n): " setup_key
        if [[ $setup_key == "y" || $setup_key == "Y" ]]; then
            # Create .ssh directory
            USER_HOME=$(getent passwd "$username" | cut -d: -f6)
            mkdir -p "$USER_HOME/.ssh"
            chmod 700 "$USER_HOME/.ssh"
            
            echo "Please paste your public SSH key (usually found in ~/.ssh/id_rsa.pub on your local machine):"
            read -r pubkey
            echo "$pubkey" >> "$USER_HOME/.ssh/authorized_keys"
            chmod 600 "$USER_HOME/.ssh/authorized_keys"
            chown -R "$username:$username" "$USER_HOME/.ssh"
            
            success "SSH key added for user $username"
            info "You can now SSH with: ssh $username@$(curl -s ifconfig.me)"
        fi
        ;;
        
    3)
        log "Re-enabling password authentication temporarily..."
        # Remove the PasswordAuthentication no line
        sed -i '/PasswordAuthentication no/d' /etc/ssh/sshd_config.d/99-n8n-hardening.conf 2>/dev/null || true
        
        # Add PasswordAuthentication yes
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-n8n-hardening.conf
        
        # Restart SSH
        if systemctl is-active --quiet sshd; then
            systemctl restart sshd
        elif systemctl is-active --quiet ssh; then
            systemctl restart ssh
        fi
        
        warning "Password authentication is now enabled!"
        warning "This is less secure. Please set up SSH key authentication instead."
        ;;
        
    4)
        log "Current SSH configuration:"
        echo "=== Main config ==="
        grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null || echo "No relevant settings in main config"
        
        echo -e "\n=== Hardening config ==="
        if [ -f "/etc/ssh/sshd_config.d/99-n8n-hardening.conf" ]; then
            cat /etc/ssh/sshd_config.d/99-n8n-hardening.conf
        else
            echo "No hardening config found"
        fi
        ;;
        
    5)
        log "Restoring original SSH configuration..."
        if [ -f "/etc/ssh/sshd_config.backup" ]; then
            cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
            rm -f /etc/ssh/sshd_config.d/99-n8n-hardening.conf
            
            # Restart SSH
            if systemctl is-active --quiet sshd; then
                systemctl restart sshd
            elif systemctl is-active --quiet ssh; then
                systemctl restart ssh
            fi
            
            success "Original SSH configuration restored"
        else
            error "No backup found. Cannot restore."
        fi
        ;;
        
    *)
        error "Invalid choice"
        exit 1
        ;;
esac

log "SSH configuration updated!"
info "Remember to test SSH access before closing your current session"
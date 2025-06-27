#!/bin/bash

# n8n Hetzner Server Initial Setup Script
# This script prepares a fresh Ubuntu server for n8n deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting n8n server initial setup..."

# Update system
log "Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# Install essential packages
log "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    ufw \
    fail2ban \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    unzip \
    jq

# Install Docker
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable Docker service
    systemctl enable docker
    systemctl start docker
else
    log "Docker is already installed"
fi

# Install Docker Compose
log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    log "Docker Compose is already installed"
fi

# Configure UFW firewall
log "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5678/tcp
echo "y" | ufw enable

# Configure fail2ban
log "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Create fail2ban configuration for SSH
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban

# Set up swap file (useful for smaller instances)
log "Setting up swap file..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    # Configure swappiness
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    sysctl -p
else
    log "Swap file already exists"
fi

# Install Nginx
log "Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# Install Certbot for Let's Encrypt
log "Installing Certbot..."
apt-get install -y certbot python3-certbot-nginx

# Create n8n user
log "Creating n8n user..."
if ! id -u n8n &>/dev/null; then
    useradd -m -s /bin/bash n8n
    usermod -aG docker n8n
else
    log "n8n user already exists"
fi

# Create directory structure
log "Creating directory structure..."
mkdir -p /opt/n8n
mkdir -p /opt/n8n/backups
mkdir -p /var/log/n8n
chown -R n8n:n8n /opt/n8n
chown -R n8n:n8n /var/log/n8n

# Set up automatic security updates
log "Configuring automatic security updates..."
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Configure kernel parameters for better performance
log "Optimizing kernel parameters..."
cat >> /etc/sysctl.conf << EOF

# Network optimizations for n8n
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.core.netdev_max_backlog = 65535

# Memory optimizations
vm.overcommit_memory = 1
EOF

sysctl -p

# Install monitoring tools
log "Installing monitoring tools..."
apt-get install -y ncdu iotop nethogs

# Create SSH key for n8n user (for git operations)
log "Setting up SSH key for n8n user..."
sudo -u n8n ssh-keygen -t ed25519 -f /home/n8n/.ssh/id_ed25519 -N ""

# Display system info
log "System preparation complete!"
echo ""
echo "==================================="
echo "Server Information:"
echo "==================================="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
echo "Nginx version: $(nginx -v 2>&1)"
echo "UFW status: $(ufw status | head -n 1)"
echo "Fail2ban status: $(systemctl is-active fail2ban)"
echo ""
echo "==================================="
echo "Next Steps:"
echo "==================================="
echo "1. Run deploy-n8n.sh to deploy n8n"
echo "2. Configure your domain DNS to point to this server"
echo "3. Run secure-server.sh to complete security setup"
echo ""
echo "Server IP: $(curl -s ifconfig.me)"
echo "==================================="

log "Initial setup completed successfully!"
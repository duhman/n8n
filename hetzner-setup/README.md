# n8n Hetzner Cloud Deployment Guide

This guide provides a complete, production-ready deployment of n8n on Hetzner Cloud with automated setup scripts, security hardening, SSL certificates, and automated backups.

## Prerequisites

- Hetzner Cloud account with SSH key added
- Domain name pointed to your server (for SSL)
- Basic Linux/SSH knowledge

## Quick Start

### 1. Create Hetzner Server

1. Log into [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Create new server:
   - **Type**: CX21 (2 vCPU, 4GB RAM, €5.83/mo) or CX31 (2 vCPU, 8GB RAM, €11.27/mo)
   - **Image**: Ubuntu 22.04 LTS
   - **Location**: Choose nearest to your users
   - **SSH Key**: Select your uploaded key
   - **Firewall**: Create new with these rules:
     - SSH (22) - Your IP only
     - HTTP (80) - All IPs
     - HTTPS (443) - All IPs
     - n8n (5678) - All IPs

### 2. Connect to Server

```bash
ssh root@YOUR_SERVER_IP
```

### 3. Clone Repository and Run Setup

```bash
# Clone your n8n repository
git clone https://github.com/duhman/n8n.git /opt/setup
cd /opt/setup/hetzner-setup

# Make scripts executable
chmod +x *.sh

# Run initial server setup
./initial-setup.sh

# Deploy n8n
./deploy-n8n.sh

# After DNS is configured, secure the server
./secure-server.sh

# Set up automated backups
./backup-setup.sh
```

## Detailed Setup Steps

### Step 1: Initial Server Setup

The `initial-setup.sh` script performs:

- System updates and essential packages installation
- Docker and Docker Compose installation
- UFW firewall configuration
- Fail2ban setup for intrusion prevention
- Swap file creation (2GB)
- Nginx installation
- n8n user creation
- Automatic security updates
- Kernel optimization

**Run:**

```bash
./initial-setup.sh
```

### Step 2: Deploy n8n

The `deploy-n8n.sh` script:

- Clones your n8n repository
- Sets up production configuration
- Generates secure passwords and encryption keys
- Configures Nginx reverse proxy
- Starts n8n with Docker Compose
- Creates systemd service for auto-start

**Run:**

```bash
./deploy-n8n.sh
```

You'll be prompted for:

- Domain name (e.g., n8n.yourdomain.com)
- Email configuration (optional)

### Step 3: Configure DNS

Before running the security script:

1. Go to your domain registrar
2. Create an A record pointing to your server IP
3. Wait for DNS propagation (5-30 minutes)

Test DNS:

```bash
dig +short yourdomain.com
# Should return your server IP
```

### Step 4: Security Hardening

The `secure-server.sh` script implements:

- SSL/TLS certificate via Let's Encrypt
- Enhanced Nginx security headers
- Rate limiting
- SSH hardening (key-only authentication)
- Advanced fail2ban rules
- Audit logging (auditd)
- Automated certificate renewal

**Run:**

```bash
./secure-server.sh
```

### Step 5: Backup Configuration

The `backup-setup.sh` script sets up:

- Daily automated backups at 2:30 AM
- 7-day retention policy
- Options for local storage or Hetzner Storage Box
- Database dumps + n8n data
- Encrypted configuration backup

**Run:**

```bash
./backup-setup.sh
```

Choose backup destination:

1. Local storage only
2. Hetzner Storage Box (recommended)
3. Custom remote location

## Post-Installation

### Access n8n

1. Open browser to `https://your-domain.com`
2. Create your first admin user
3. Start building workflows!

### Important Commands

**Service Management:**

```bash
# View logs
docker compose -f /opt/n8n/n8n-production/docker-compose.yml logs -f

# Restart n8n
systemctl restart n8n

# Stop n8n
docker compose -f /opt/n8n/n8n-production/docker-compose.yml down

# Start n8n
docker compose -f /opt/n8n/n8n-production/docker-compose.yml up -d
```

**Backup Management:**

```bash
# Run manual backup
sudo -u n8n /usr/local/bin/n8n-backup.sh

# Check backup status
/usr/local/bin/n8n-backup-status.sh

# Restore from backup
./restore-backup.sh /opt/n8n/backups/n8n_backup_TIMESTAMP.tar.gz
```

**Security Monitoring:**

```bash
# Check security status
/usr/local/bin/n8n-security-check.sh

# View fail2ban status
fail2ban-client status

# Check blocked IPs
fail2ban-client status n8n-auth
```

## Maintenance

### Regular Updates

```bash
# Update system
apt update && apt upgrade

# Check current n8n version
cd /opt/setup/hetzner-setup
./check-n8n-version.sh

# Update n8n to specific version (e.g., 1.100.1)
./update-n8n.sh 1.100.1

# Or update to latest version
./update-n8n.sh latest
```

The update script automatically:

- Creates a full backup before updating
- Updates the Docker image
- Verifies the update was successful
- Provides rollback instructions if needed

### SSL Certificate Renewal

Certificates auto-renew via cron. To manually renew:

```bash
certbot renew
systemctl reload nginx
```

### Monitoring

Check these regularly:

- Disk space: `df -h`
- Memory usage: `free -h`
- Docker stats: `docker stats`
- Logs: `tail -f /var/log/nginx/n8n_error.log`

## Troubleshooting

### n8n Not Accessible

1. Check services:

   ```bash
   docker compose -f /opt/n8n/n8n-production/docker-compose.yml ps
   ```

2. Check Nginx:

   ```bash
   systemctl status nginx
   nginx -t
   ```

3. Check firewall:

   ```bash
   ufw status
   ```

### Database Issues

1. Check PostgreSQL:

   ```bash
   docker compose -f /opt/n8n/n8n-production/docker-compose.yml logs postgres
   ```

2. Access database:

   ```bash
   docker compose -f /opt/n8n/n8n-production/docker-compose.yml exec postgres psql -U n8n
   ```

### Restore from Backup

If something goes wrong:

```bash
cd /opt/setup/hetzner-setup

# List available backups
ls -la /opt/n8n-backups/

# Restore from specific backup
./restore-from-backup.sh /opt/n8n-backups/n8n-backup-TIMESTAMP.tar.gz
```

The restore script will:

- Stop n8n services
- Create a safety backup of current state
- Restore database and files from backup
- Restart services and verify functionality

## Security Considerations

- **Encryption Key**: Keep your `N8N_ENCRYPTION_KEY` safe! It's in `/opt/n8n/n8n-production/.env`
- **Backups**: Store backups securely, they contain sensitive data
- **SSH**: Only key-based authentication is allowed
- **Firewall**: Only required ports are open
- **Updates**: Automatic security updates are enabled

## File Locations

- **n8n Installation**: `/opt/n8n/`
- **Production Config**: `/opt/n8n/n8n-production/`
- **Environment File**: `/opt/n8n/n8n-production/.env`
- **Data Directory**: `/opt/n8n/n8n-production/data/`
- **Backups**: `/opt/n8n/backups/`
- **Nginx Config**: `/etc/nginx/sites-available/n8n`
- **Logs**: `/var/log/n8n/`

## Support

For issues:

1. Check logs: `docker compose logs`
2. Review this documentation
3. Check [n8n documentation](https://docs.n8n.io)
4. Visit [n8n community forum](https://community.n8n.io)

## Cost Estimation

- **Hetzner CX21**: €5.83/month (adequate for small-medium usage)
- **Hetzner CX31**: €11.27/month (recommended for production)
- **Storage Box** (optional): €3.36/month (BX11, 1TB)
- **Total**: €9-15/month for a production n8n instance

## License

These deployment scripts are provided as-is. n8n is licensed under [Apache 2.0 with Commons Clause](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).

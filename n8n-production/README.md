# n8n Production Setup with Docker and PostgreSQL

This directory contains a production-ready Docker Compose setup for n8n with PostgreSQL as the database backend.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- 10GB+ free disk space
- Basic knowledge of Docker and command line

## Quick Start

1. **Clone and navigate to the production directory:**
   ```bash
   cd n8n-production
   ```

2. **Copy and configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and update:
   - Database passwords (use strong, unique passwords)
   - Generate a new encryption key: `openssl rand -hex 32`
   - Update `N8N_HOST` and `WEBHOOK_URL` for your domain
   - Configure timezone settings

3. **Start the services:**
   ```bash
   docker-compose up -d
   ```

4. **Access n8n:**
   - Open http://localhost:5678 in your browser
   - Create your admin account on first access

## Directory Structure

```
n8n-production/
├── docker-compose.yml       # Main orchestration file
├── .env                    # Environment variables (git-ignored)
├── .env.example            # Environment template
├── backup.sh               # Automated backup script
├── restore.sh              # Restore from backup script
├── data/
│   ├── n8n/               # n8n persistent data
│   └── postgres/          # PostgreSQL data
├── backups/               # Backup storage
└── local-files/           # Shared files directory
```

## Configuration

### Essential Environment Variables

- `POSTGRES_PASSWORD`: Strong password for PostgreSQL
- `N8N_ENCRYPTION_KEY`: 32-byte hex key for credential encryption
- `N8N_HOST`: Your domain name
- `WEBHOOK_URL`: Full URL for webhooks (https://your-domain.com/)
- `GENERIC_TIMEZONE`: Timezone for scheduling

### Security Best Practices

1. **Strong Passwords**: Use complex passwords for database
2. **Encryption Key**: Never share or commit your encryption key
3. **Network Isolation**: Services communicate on internal network
4. **Regular Updates**: Keep Docker images updated
5. **Firewall**: Only expose necessary ports (5678 by default)

## Backup and Restore

### Automated Backups

Run the backup script:
```bash
./backup.sh
```

This creates a timestamped backup containing:
- PostgreSQL database dump
- n8n configuration and credentials
- Retains last 7 days of backups

### Schedule Daily Backups

Add to crontab:
```bash
0 2 * * * cd /path/to/n8n-production && ./backup.sh >> backups/backup.log 2>&1
```

### Restore from Backup

```bash
./restore.sh backups/n8n_backup_YYYYMMDD_HHMMSS_complete.tar.gz
```

## Maintenance

### View Logs

```bash
# All services
docker-compose logs -f

# n8n only
docker-compose logs -f n8n

# PostgreSQL only
docker-compose logs -f postgres
```

### Update n8n

1. Check for breaking changes: https://github.com/n8n-io/n8n/releases
2. Create a backup: `./backup.sh`
3. Update and restart:
   ```bash
   docker-compose pull n8n
   docker-compose up -d n8n
   ```

### Database Maintenance

Connect to PostgreSQL:
```bash
docker-compose exec postgres psql -U n8n_prod_user -d n8n_production
```

Check database size:
```sql
SELECT pg_database_size('n8n_production');
```

## Monitoring

### Health Check

```bash
curl http://localhost:5678/healthz
```

### Metrics (if enabled)

```bash
curl http://localhost:5678/metrics
```

### Resource Usage

```bash
docker stats
```

## Scaling

### Horizontal Scaling with Workers

For high-volume workflows, enable queue mode:

1. Add Redis service to docker-compose.yml
2. Set `EXECUTIONS_MODE=queue` in .env
3. Run separate worker containers

### Performance Tuning

- Increase PostgreSQL connection pool
- Adjust container resource limits
- Enable execution pruning
- Use external file storage for large files

## Troubleshooting

### n8n Won't Start

1. Check logs: `docker-compose logs n8n`
2. Verify PostgreSQL is healthy: `docker-compose ps`
3. Ensure encryption key is set correctly
4. Check file permissions on data directories

### Database Connection Issues

1. Verify PostgreSQL is running
2. Check credentials in .env match
3. Ensure network connectivity between containers
4. Review PostgreSQL logs

### Lost Encryption Key

- Without the encryption key, credentials cannot be decrypted
- Always backup your .env file securely
- Consider using Docker secrets for production

### High Memory Usage

1. Enable execution pruning in n8n settings
2. Regularly clean old execution data
3. Increase container memory limits if needed

## SSL/TLS Setup (Optional)

For production use with HTTPS, see `docker-compose.override.yml.example` for Traefik integration.

## Support

- Documentation: https://docs.n8n.io
- Community Forum: https://community.n8n.io
- GitHub Issues: https://github.com/n8n-io/n8n/issues

## License

n8n is fair-code licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).
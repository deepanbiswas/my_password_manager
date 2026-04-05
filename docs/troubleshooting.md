# Troubleshooting Guide

## Common Issues and Solutions

### SSL Certificate Not Renewing

**Symptoms:**
- HTTPS connection fails
- Certificate expiration warnings
- Caddy logs show certificate errors

**Solutions:**

```bash
# Check Caddy logs
docker logs caddy

# Manually renew (if using Certbot)
sudo certbot renew --dry-run

# Restart Caddy container
docker-compose restart caddy

# Verify certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

**Prevention:**
- Ensure port 80 is accessible for Let's Encrypt validation
- Check DNS records are correct
- Monitor Caddy logs regularly

### Container Won't Start

**Symptoms:**
- `docker-compose up` fails
- Container exits immediately
- Service not accessible

**Solutions:**

```bash
# Check logs
docker-compose logs vaultwarden

# Check disk space
df -h

# Check permissions
ls -la /opt/vaultwarden/vaultwarden/data

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Verify docker-compose file syntax
docker-compose config
```

**Common Causes:**
- Insufficient disk space
- Incorrect file permissions
- Port conflicts
- Invalid configuration

### Backup Fails

**Symptoms:**
- Backup script exits with error
- No backups in Google Drive
- Backup logs show errors

**Solutions:**

Use the remote name from `/opt/vaultwarden/.env` (`RCLONE_REMOTE_NAME`, default `gdrive`). Replace `<remote>` below.

```bash
cd /opt/vaultwarden
REMOTE="${RCLONE_REMOTE_NAME:-gdrive}"
grep -E '^RCLONE_REMOTE_NAME=' .env 2>/dev/null || true

# Check Rclone configuration for that remote
rclone config show "$REMOTE"

# Test Rclone connection
rclone lsd "${REMOTE}:"

# Check encryption key is set after sourcing .env
set -a && source .env && set +a && test -n "${BACKUP_ENCRYPTION_KEY:-}" && echo "BACKUP_ENCRYPTION_KEY is set"

# Test backup manually
./scripts/backup.sh

# Check backup logs
tail -n 50 /var/log/vaultwarden-backup.log

# Verify Google Drive path used by backup.sh
rclone ls "${REMOTE}:vaultwarden-backups/"
```

**Rclone setup:** OAuth with Google Drive — see [Rclone: Google Drive for Vaultwarden backups](rclone-google-drive.md). Typical failures:

| Symptom | Check |
|---------|--------|
| `403` / API not enabled | Enable **Google Drive API** on the GCP project for your OAuth client |
| OAuth / consent errors | Consent screen in Testing: add your Google account as a **test user** |
| `vaultwarden-backups` missing | Run once: `rclone mkdir "<remote>:vaultwarden-backups"` |
| Cron never writes logs / nightly backup never appears | The cron line appends to `/var/log/vaultwarden-backup.log`. That file must exist and be **writable by the same user that owns the crontab** (usually your deploy user). If it is missing or root-owned, the job can fail before `backup.sh` runs. Fix once: `sudo touch /var/log/vaultwarden-backup.log && sudo chown "$(whoami):$(whoami)" /var/log/vaultwarden-backup.log`. Re-run **`deploy-to-vm.sh`** from a recent repo (it creates this file automatically) or apply the same two lines on the VM. |

**Common Causes:**
- Rclone not configured correctly (remote name mismatch with `RCLONE_REMOTE_NAME` in `.env`)
- Google Drive API quota exceeded or API not enabled
- Encryption key missing or incorrect
- Network connectivity issues

### Service Not Accessible

**Symptoms:**
- Cannot access https://your-domain.com
- Connection timeout
- 502 Bad Gateway error

**Solutions:**

```bash
# Check container status
docker ps

# Check service logs
docker-compose logs -f

# Test local connection
curl http://localhost:80

# Check firewall
sudo ufw status

# Verify DNS
nslookup your-domain.com

# Check reverse proxy
docker logs caddy
```

### Database Issues

**Symptoms:**
- Login fails
- Data not loading
- Database locked errors

**Solutions:**

```bash
cd /opt/vaultwarden
# Host sqlite3 on bind-mounted DB (image has no sqlite3 binary)
sqlite3 vaultwarden/data/db.sqlite3 "PRAGMA integrity_check;"

# Vacuum database (stop vaultwarden first if you get a database lock)
sqlite3 vaultwarden/data/db.sqlite3 "VACUUM;"

# Check database size
ls -lh vaultwarden/data/db.sqlite3

# Backup before repair
sqlite3 vaultwarden/data/db.sqlite3 ".backup /opt/vaultwarden/backups/db.repair.backup.sqlite3"
```

## Emergency Procedures

### Emergency Stop

**When to use:** Service needs immediate shutdown (security incident, critical error)

```bash
cd /opt/vaultwarden
docker-compose down
```

### Emergency Restore

**When to use:** Data corruption, accidental deletion, or service compromise

```bash
cd /opt/vaultwarden
./scripts/restore.sh <latest-backup-file>
```

**Steps:**
1. Stop services: `docker-compose stop`
2. Run restore script with backup filename
3. Verify data integrity
4. Restart services: `docker-compose start`

### Complete Reset

**When to use:** Complete system failure, need to start fresh

1. Stop all services: `docker-compose down`
2. Backup current data (if accessible)
3. Remove volumes: `docker-compose down -v`
4. Restore from backup: `./scripts/restore.sh <backup-file>`
5. Reconfigure if needed
6. Start services: `docker-compose up -d`

## Debugging Steps

### Step 1: Check Service Status

```bash
# All containers
docker ps -a

# Specific service
docker-compose ps

# Service logs
docker-compose logs -f vaultwarden
```

### Step 2: Verify Configuration

```bash
# Environment variables
cat /opt/vaultwarden/.env

# Docker Compose config
docker-compose config

# Caddy configuration
cat /opt/vaultwarden/caddy/Caddyfile
```

### Step 3: Test Connectivity

```bash
# Local connection
curl http://localhost:80

# External connection
curl https://your-domain.com

# Database query (host sqlite3 on bind-mounted file)
cd /opt/vaultwarden && sqlite3 vaultwarden/data/db.sqlite3 "SELECT COUNT(*) FROM users;"
```

### Step 4: Check Resources

```bash
# Disk space
df -h

# Memory usage
free -h

# CPU usage
top

# Docker resources
docker system df
```

## Log Locations

### Key Log Files

- **Vaultwarden logs**: `docker logs vaultwarden`
- **Caddy logs**: `docker logs caddy`
- **Backup logs**: `/var/log/vaultwarden-backup.log`
- **System logs**: `/var/log/syslog`
- **Cloud-init logs**: `/var/log/cloud-init.log`

### Viewing Logs

```bash
# Real-time logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker logs vaultwarden --tail=50 -f

# Backup logs
tail -f /var/log/vaultwarden-backup.log
```

## Performance Issues

### Slow Response Times

**Diagnosis:**
```bash
# Check container resources
docker stats

# Check database size (host sqlite3)
cd /opt/vaultwarden && sqlite3 vaultwarden/data/db.sqlite3 "SELECT page_count * page_size / 1024 / 1024 AS size_mb FROM pragma_page_count(), pragma_page_size();"

# Check disk I/O
iostat -x 1
```

**Solutions:**
- Increase VM resources (CPU/RAM)
- Optimize database (VACUUM, ANALYZE)
- Check for disk space issues
- Review attachment storage usage

### High Memory Usage

**Diagnosis:**
```bash
# Check memory
free -h
docker stats
```

**Solutions:**
- Restart containers: `docker-compose restart`
- Clean up Docker: `docker system prune`
- Increase VM RAM
- Check for memory leaks in logs

## Network Issues

### Cannot Access from Internet

**Checklist:**
1. Verify DNS points to correct IP
2. Check firewall allows ports 80/443
3. Verify Azure NSG rules
4. Test from different network
5. Check reverse proxy is running

### Internal Network Issues

**Checklist:**
1. Verify Docker network: `docker network ls`
2. Check container connectivity: `docker exec vaultwarden ping caddy`
3. Verify service ports: `netstat -tulpn`
4. Check reverse proxy configuration

## Getting Help

### Information to Collect

When seeking help, provide:
1. Error messages from logs
2. Container status: `docker ps -a`
3. System resources: `df -h`, `free -h`
4. Configuration (sanitized): `docker-compose config`
5. Recent changes made

### Useful Commands

```bash
# System information
uname -a
docker --version
docker-compose --version

# Service status
systemctl status docker
docker-compose ps

# Resource usage
df -h
free -h
docker stats --no-stream
```

## Prevention

### Regular Maintenance

1. **Monitor logs** weekly
2. **Check disk space** regularly
3. **Verify backups** monthly
4. **Update containers** (automated via Watchtower)
5. **Review security** quarterly

### Best Practices

1. **Test backups** regularly
2. **Monitor resource usage**
3. **Keep documentation updated**
4. **Review logs** for errors
5. **Update dependencies** when available

## Summary

Most issues can be resolved by checking logs, verifying configuration, and ensuring resources are available. For critical issues, use emergency procedures to restore from backups. Regular monitoring and maintenance prevent most problems.

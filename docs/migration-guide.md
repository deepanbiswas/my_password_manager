# Migration Guide

## Overview

This guide covers migrating the password manager setup between different infrastructure providers or upgrading to new infrastructure.

## Migrating to New Infrastructure

### Step-by-Step Migration Process

#### Step 1: Prepare New Server

1. **Provision New VM**: Create Ubuntu 22.04 LTS VM on target provider
2. **Configure Network**: Set up firewall (ports 80/443)
3. **Run Setup Script**: Execute `scripts/setup.sh` on new VM
4. **Verify Prerequisites**: Ensure Docker, Docker Compose, Rclone are installed

#### Step 2: Configure Rclone

```bash
# On new server, configure Rclone
rclone config

# Test connection
rclone lsd gdrive:
```

#### Step 3: Restore Backup

```bash
# Set encryption key in .env
echo "BACKUP_ENCRYPTION_KEY=<your-key>" >> /opt/vaultwarden/.env

# List available backups
cd /opt/vaultwarden
./scripts/restore.sh

# Restore specific backup
./scripts/restore.sh vaultwarden_backup_YYYYMMDD_HHMMSS.tar.gz.gpg
```

#### Step 4: Update DNS

1. **Get New IP**: Note the new server's public IP address
2. **Update DNS**: Point domain A record to new IP
3. **Wait for Propagation**: DNS changes can take up to 48 hours (usually < 1 hour)
4. **Verify DNS**: `nslookup your-domain.com`

#### Step 5: Verify Deployment

1. **Test HTTPS**: Access `https://your-domain.com`
2. **Verify Login**: Test user authentication
3. **Check Data**: Verify password entries are present
4. **Test Attachments**: Verify file attachments are accessible
5. **Check Backups**: Verify backup automation is working

#### Step 6: Decommission Old Server

1. **Wait for Verification Period**: Keep old server running for 1-2 weeks
2. **Monitor New Server**: Ensure no issues arise
3. **Final Backup**: Take one last backup from old server
4. **Stop Services**: `docker-compose down` on old server
5. **Delete Resources**: Remove old VM and associated resources

## Vendor-Specific Notes

### Azure VM

**Requirements:**
- Use Standard_B2s or higher (2 vCPU, 4 GB RAM)
- Enable managed disk encryption
- Configure Network Security Group (allow 80/443 only)

**Migration Steps:**
1. Create new VM in Azure
2. Configure NSG rules
3. Follow standard migration process
4. Update DNS to new public IP

### AWS EC2

**Requirements:**
- Use t3.small or higher
- Configure Security Group (allow 80/443 only)
- Use EBS encryption for volumes

**Migration Steps:**
1. Launch EC2 instance (Ubuntu 22.04)
2. Configure Security Group
3. Follow standard migration process
4. Update DNS to new Elastic IP

### DigitalOcean

**Requirements:**
- Use 2GB/2vCPU Droplet minimum
- Configure Firewall (allow 80/443 only)

**Migration Steps:**
1. Create Droplet (Ubuntu 22.04)
2. Configure Firewall rules
3. Follow standard migration process
4. Update DNS to new Droplet IP

### Local Machine

**Requirements:**
- Ensure static IP or dynamic DNS
- Port forward 80/443 from router
- Consider using Tailscale/ZeroTier for secure access

**Migration Steps:**
1. Install Ubuntu 22.04 on local machine
2. Configure port forwarding on router
3. Set up dynamic DNS (if no static IP)
4. Follow standard migration process
5. Update DNS to local IP or dynamic DNS hostname

## Migration Scenarios

### Scenario 1: Azure to Azure (Upgrade VM)

**Use Case:** Moving to larger VM or different region

**Process:**
1. Create new VM with desired specs
2. Follow standard migration steps
3. Update DNS
4. Delete old VM after verification

### Scenario 2: Azure to Cheaper VPS

**Use Case:** Azure credits expired, moving to Hetzner/DigitalOcean

**Process:**
1. Provision VM on new provider
2. Follow standard migration steps
3. Update DNS
4. Cancel Azure subscription after verification

### Scenario 3: VPS to Local Machine

**Use Case:** Moving to self-hosted local setup

**Process:**
1. Set up local machine with Ubuntu
2. Configure network (port forwarding, dynamic DNS)
3. Follow standard migration steps
4. Update DNS to local IP or dynamic DNS

### Scenario 4: Disaster Recovery

**Use Case:** Complete infrastructure failure, restore from backup

**Process:**
1. Provision new VM on any provider
2. Run setup script
3. Configure Rclone
4. Restore from latest backup
5. Update DNS
6. Verify all functionality

## Pre-Migration Checklist

- [ ] Latest backup verified and accessible
- [ ] Backup encryption key securely stored
- [ ] Rclone configured and tested
- [ ] New server provisioned and configured
- [ ] DNS update plan prepared
- [ ] Old server backup taken
- [ ] Migration window scheduled

## Post-Migration Checklist

- [ ] HTTPS accessible on new server
- [ ] User authentication working
- [ ] All password entries present
- [ ] Attachments accessible
- [ ] Backup automation configured
- [ ] Monitoring set up
- [ ] DNS fully propagated
- [ ] Old server decommissioned (after verification period)

## Rollback Procedure

If migration fails, rollback to old server:

1. **Stop New Server**: `docker-compose down` on new server
2. **Update DNS**: Point domain back to old server IP
3. **Verify Old Server**: Ensure old server is still running
4. **Test Access**: Verify old server is accessible
5. **Investigate Issues**: Review logs and fix problems
6. **Retry Migration**: Once issues resolved, retry migration

## Migration Best Practices

1. **Test First**: Test migration process on staging environment
2. **Backup Before**: Always take fresh backup before migration
3. **Maintain Both**: Keep both servers running during transition
4. **Monitor Closely**: Watch logs and metrics during migration
5. **Verify Everything**: Test all functionality before decommissioning old server
6. **Document Changes**: Keep notes of any configuration differences

## Common Migration Issues

### Issue: DNS Not Propagating

**Solution:**
- Wait longer (up to 48 hours)
- Check DNS TTL settings
- Use different DNS provider
- Clear local DNS cache

### Issue: Backup Restore Fails

**Solution:**
- Verify encryption key is correct
- Check Rclone connection
- Verify backup file is complete
- Check disk space on new server

### Issue: Service Not Starting

**Solution:**
- Check Docker is running
- Verify file permissions
- Check disk space
- Review container logs

## Summary

Migration between providers is straightforward when following the standard process: prepare new server, restore backup, update DNS, verify, and decommission old server. Always maintain backups and keep old server running during verification period.

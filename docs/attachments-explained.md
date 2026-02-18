# Attachments and Attachment Store Explained

## What are Attachments?

**Attachments** in Vaultwarden/Bitwarden are files that users can securely attach to their password entries or secure notes. These files are stored alongside vault data and are encrypted using the same zero-knowledge architecture.

### Examples of Attachments

- **Document files**: PDFs, Word documents, spreadsheets, text files
- **Image files**: Screenshots, scanned documents, photos
- **Certificate files**: SSL certificates, SSH keys, PGP keys
- **Archive files**: ZIP files, encrypted archives
- **Any file type**: Users can attach any file they want to store securely

## Attachment Store Architecture

### Storage Location

In this setup, attachments are stored at:
```
/opt/vaultwarden/vaultwarden/data/attachments/
```

### Storage Type

- **Type**: Local filesystem (mounted as Docker volume)
- **Organization**: Files are organized by user ID and vault entry ID
- **Structure**: Hierarchical directory structure for efficient access

### Directory Structure Example

```
attachments/
├── {user-id}/
│   ├── {entry-id}/
│   │   ├── file1.pdf
│   │   ├── file2.jpg
│   │   └── metadata.json
│   └── {entry-id-2}/
│       └── certificate.pem
```

## Encryption and Security

### Zero-Knowledge Encryption

- **Client-Side Encryption**: Attachments are encrypted on the client device before upload
- **Server Storage**: Server stores only encrypted file blobs
- **Key Management**: Encryption keys derived from user's master password (never stored)
- **Server Access**: Server cannot decrypt attachments (zero-knowledge)

### Encryption Details

- **Algorithm**: AES-256-CBC (same as vault data)
- **Key Derivation**: PBKDF2 with 100,000 iterations
- **Initialization Vector**: Unique IV per file
- **Integrity**: HMAC-SHA256 for data integrity verification

## Size Limits

### Default Limits

- **Per User**: 1 GB (free tier)
- **Per File**: Configurable (default: varies by client)
- **Total Storage**: Limited by VM disk space

### Configuration

Size limits can be configured in Vaultwarden via environment variables:
- `ATTACHMENT_LIMIT`: Maximum attachment size per user
- `MAX_LOGIN_ATTACHMENTS`: Maximum attachments per login entry

## Database vs File Storage

### Why Separate Storage?

Attachments are stored separately from the SQLite database for several reasons:

1. **Performance**: Large files would bloat the database
2. **Scalability**: File system handles large files more efficiently
3. **Backup**: Easier to backup files separately
4. **Management**: Simpler to manage and clean up files

### What's Stored Where

**SQLite Database Stores:**
- File metadata (names, sizes, paths)
- User associations
- Entry associations
- Upload timestamps

**File System Stores:**
- Actual file content (encrypted)
- File organization structure

## Backup Considerations

### Backup Strategy

Attachments are included in the backup process:

1. **Database Backup**: Includes attachment metadata
2. **File Backup**: Attachments directory is compressed and backed up
3. **Encryption**: Both database and attachments are encrypted together
4. **Restore**: Both are restored together to maintain consistency

### Backup Script Behavior

The backup script (`scripts/backup.sh`):
- Creates a compressed archive of the attachments directory
- Includes it in the encrypted backup package
- Maintains directory structure for proper restoration

## Performance Optimization

### Storage Optimization

1. **Disk Space**: Monitor attachment storage usage
2. **Cleanup**: Implement retention policies for old attachments
3. **Compression**: Attachments are compressed during backup
4. **Deduplication**: Consider deduplication for identical files (if needed)

### Access Optimization

1. **Caching**: Reverse proxy can cache static content
2. **CDN**: Consider CDN for frequently accessed files (advanced)
3. **Storage Tier**: Use appropriate storage tier for attachment volume

## Troubleshooting

### Common Issues

**Issue: Attachments not uploading**
- Check disk space: `df -h`
- Verify permissions: `ls -la /opt/vaultwarden/vaultwarden/data/attachments`
- Check Vaultwarden logs: `docker logs vaultwarden`

**Issue: Attachments not accessible**
- Verify encryption key is correct
- Check file permissions
- Verify attachment metadata in database

**Issue: Disk space full**
- Clean up old attachments
- Increase VM disk size
- Implement attachment retention policy

### Maintenance Commands

```bash
# Check attachment storage size
du -sh /opt/vaultwarden/vaultwarden/data/attachments

# List all attachments
find /opt/vaultwarden/vaultwarden/data/attachments -type f

# Check disk space
df -h /opt/vaultwarden/vaultwarden/data/attachments
```

## Best Practices

1. **Regular Monitoring**: Monitor attachment storage usage
2. **Backup Verification**: Verify attachments are included in backups
3. **Size Limits**: Set appropriate size limits per user
4. **Retention Policy**: Implement cleanup for old/unused attachments
5. **Security**: Ensure proper file permissions (600 for sensitive files)

## Summary

Attachments provide a secure way to store files alongside password entries, using the same zero-knowledge encryption architecture. They are stored separately from the database for performance and scalability, but are backed up and restored together to maintain data consistency.

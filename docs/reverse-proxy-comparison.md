# Reverse Proxy Comparison: Caddy vs Nginx

## Why Caddy is Recommended

Caddy is the **recommended** reverse proxy for this setup due to the following advantages:

### Automatic SSL Certificate Management
- **Caddy**: Automatically obtains and renews Let's Encrypt certificates with zero configuration
- **Nginx**: Requires manual setup with Certbot and cron jobs for renewal

### Configuration Simplicity
- **Caddy**: Simple, declarative Caddyfile syntax - minimal configuration needed
- **Nginx**: More verbose configuration files, requires deeper understanding

### Built-in Features
- **Caddy**: Built-in HTTP/2, compression, and security headers
- **Nginx**: Requires additional modules and configuration for similar features

### Maintenance
- **Caddy**: Automatic certificate renewal, no manual intervention
- **Nginx**: Requires monitoring and manual renewal setup

## Feature Comparison

| Feature | Caddy | Nginx |
|---------|-------|-------|
| **Automatic HTTPS** | ✅ Built-in | ❌ Requires Certbot |
| **Certificate Renewal** | ✅ Automatic | ⚠️ Manual/Cron |
| **Configuration Complexity** | ✅ Simple | ⚠️ More complex |
| **Performance** | ✅ Excellent | ✅ Excellent |
| **HTTP/2 Support** | ✅ Built-in | ✅ Available |
| **WebSocket Support** | ✅ Native | ✅ Available |
| **Rate Limiting** | ✅ Built-in | ✅ Available |
| **Security Headers** | ✅ Easy | ⚠️ Manual config |

## Use Case Analysis

### Choose Caddy If:
- You want zero-touch SSL certificate management
- You prefer simpler configuration
- You want automatic certificate renewal
- You're deploying a personal/small-scale setup

### Choose Nginx If:
- You need advanced routing rules
- You have existing Nginx expertise
- You require specific Nginx modules
- You're managing multiple complex services

## Nginx Alternative Configuration

If you prefer to use Nginx instead of Caddy, use the following configuration:

### Nginx Configuration (`nginx/nginx.conf`)

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location / {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /notifications/hub {
        proxy_pass http://vaultwarden:3012;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Certbot Configuration for Nginx

1. **Install Certbot:**
```bash
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx
```

2. **Obtain Certificate:**
```bash
sudo certbot --nginx -d your-domain.com
```

3. **Test Renewal:**
```bash
sudo certbot renew --dry-run
```

4. **Set Up Auto-Renewal (Cron):**
```bash
# Add to crontab (crontab -e)
0 0,12 * * * certbot renew --quiet
```

### Docker Compose Update for Nginx

Update your `docker-compose.yml` to use Nginx instead of Caddy:

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/ssl:/etc/letsencrypt
    networks:
      - vaultwarden-network
    depends_on:
      - vaultwarden
```

## Migration from Caddy to Nginx

If you're currently using Caddy and want to migrate to Nginx:

1. **Stop Caddy container:**
```bash
docker-compose stop caddy
```

2. **Backup Caddy configuration:**
```bash
cp -r caddy/ caddy-backup/
```

3. **Set up Nginx configuration** (use config above)

4. **Obtain SSL certificates with Certbot:**
```bash
sudo certbot certonly --standalone -d your-domain.com
```

5. **Update docker-compose.yml** to use Nginx service

6. **Start Nginx:**
```bash
docker-compose up -d nginx
```

7. **Verify HTTPS is working:**
```bash
curl -I https://your-domain.com
```

8. **Set up certificate auto-renewal** (see Certbot section above)

## Recommendation

For this self-hosted password manager setup, **Caddy is strongly recommended** due to:
- Zero-configuration SSL certificate management
- Automatic certificate renewal
- Simpler maintenance
- Built-in security features

However, Nginx is a perfectly valid alternative if you have specific requirements or existing expertise.

# Public Access Setup Guide

Complete guide for exposing the Zoom Bot Dashboard and API publicly on your server.

## Prerequisites

1. **Server Requirements:**
   - Public IP address or domain name
   - Ports 80, 443 open in firewall
   - Domain name (optional but recommended)
   - SSL certificate (Let's Encrypt recommended)

2. **Current Setup:**
   - API: `http://localhost:3000`
   - Dashboard: `http://localhost:8080`
   - Bot Server: `http://localhost:3001`

## Method 1: Nginx Reverse Proxy (Recommended)

### Step 1: Install Nginx on Server

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
```

### Step 2: Create Nginx Configuration

Create `/etc/nginx/sites-available/zoom-bot-dashboard`:

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS Configuration
server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Certificate (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Dashboard UI (Frontend)
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # API Endpoints
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS Headers (if needed)
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        # Handle preflight requests
        if ($request_method = OPTIONS) {
            return 204;
        }
    }

    # Health Check
    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }

    # Bot Server API (if needed publicly)
    location /bot-api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Logging
    access_log /var/log/nginx/zoom-dashboard-access.log;
    error_log /var/log/nginx/zoom-dashboard-error.log;
}
```

### Step 3: Enable Site

```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Step 4: Setup SSL Certificate (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal (already configured by certbot)
sudo certbot renew --dry-run
```

## Method 2: Direct Port Exposure (Not Recommended for Production)

### Option A: Expose Ports Directly

```bash
# Update docker-compose.full.yml
# Change ports from:
ports:
  - "3000:3000"  # localhost only
# To:
ports:
  - "0.0.0.0:3000:3000"  # all interfaces
```

**Security Warning:** This exposes services without SSL and authentication.

### Option B: Firewall Rules

```bash
# Allow ports
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check status
sudo ufw status
```

## Method 3: Cloudflare Tunnel (No Port Opening Required)

### Step 1: Install Cloudflared

```bash
# Download and install
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

### Step 2: Create Tunnel

```bash
# Login
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create zoom-dashboard

# Create config file: ~/.cloudflared/config.yml
tunnel: <tunnel-id>
credentials-file: /home/user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: dashboard.your-domain.com
    service: http://localhost:8080
  - hostname: api.your-domain.com
    service: http://localhost:3000
  - service: http_status:404
```

### Step 3: Run Tunnel

```bash
# Run as service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

## Update Dashboard to Use Public API

### Step 1: Update Dashboard Configuration

Edit `dashboard/app.js`:

```javascript
// Change from:
const API_BASE_URL = 'http://localhost:3000';

// To:
const API_BASE_URL = window.location.origin; // Auto-detect
// Or:
const API_BASE_URL = 'https://your-domain.com'; // Explicit
```

### Step 2: Update CORS in API

Edit `api/server.js` to allow your domain:

```javascript
app.use(cors({
  origin: [
    'https://your-domain.com',
    'https://www.your-domain.com',
    'http://localhost:8080' // For local testing
  ],
  credentials: true
}));
```

## Security Best Practices

### 1. Rate Limiting

Add to nginx config:

```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=dashboard_limit:10m rate=5r/s;

location /api {
    limit_req zone=api_limit burst=20 nodelay;
    # ... rest of config
}
```

### 2. API Authentication

Consider adding API keys or JWT tokens for API endpoints.

### 3. Firewall Configuration

```bash
# Only allow necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 4. Fail2Ban

```bash
# Install
sudo apt install fail2ban

# Configure for nginx
sudo nano /etc/fail2ban/jail.local
```

## Testing Public Access

### 1. Test Dashboard

```bash
# From external machine
curl https://your-domain.com
curl https://your-domain.com/api/health
```

### 2. Test API

```bash
curl https://your-domain.com/api/bot-servers
curl -X POST https://your-domain.com/api/meetings \
  -H "Content-Type: application/json" \
  -d '{"meetingId":"123","password":"456","membersCount":10}'
```

### 3. Check SSL

```bash
# Test SSL certificate
openssl s_client -connect your-domain.com:443

# Online check
# Visit: https://www.ssllabs.com/ssltest/
```

## Troubleshooting

### Issue: 502 Bad Gateway

```bash
# Check if services are running
docker compose -f docker-compose.full.yml ps

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Test backend connectivity
curl http://localhost:3000/health
```

### Issue: CORS Errors

```bash
# Update CORS in api/server.js
# Add your domain to allowed origins
```

### Issue: SSL Certificate Not Working

```bash
# Check certificate
sudo certbot certificates

# Renew manually
sudo certbot renew

# Check nginx config
sudo nginx -t
```

### Issue: Services Not Accessible

```bash
# Check firewall
sudo ufw status

# Check if ports are listening
sudo netstat -tulpn | grep -E '3000|8080|80|443'

# Check docker ports
docker compose -f docker-compose.full.yml ps
```

## Quick Setup Script

Create `setup-public-access.sh`:

```bash
#!/bin/bash
set -e

DOMAIN=$1
EMAIL=$2

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: ./setup-public-access.sh your-domain.com your-email@example.com"
    exit 1
fi

# Install nginx
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Create nginx config
sudo tee /etc/nginx/sites-available/zoom-bot-dashboard > /dev/null <<EOF
# ... (nginx config from above)
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive

# Setup auto-renewal
sudo systemctl enable certbot.timer

echo "✅ Public access setup complete!"
echo "Dashboard: https://$DOMAIN"
echo "API: https://$DOMAIN/api"
```

## Production Checklist

- [ ] Domain name configured
- [ ] DNS A record pointing to server IP
- [ ] SSL certificate installed and auto-renewing
- [ ] Nginx reverse proxy configured
- [ ] Firewall rules set (only 80, 443 open)
- [ ] CORS configured for your domain
- [ ] Rate limiting enabled
- [ ] Dashboard updated to use public API URL
- [ ] Health checks working
- [ ] Logs configured and monitored
- [ ] Backup strategy in place

## Access URLs

After setup:
- **Dashboard:** `https://your-domain.com`
- **API:** `https://your-domain.com/api`
- **Health Check:** `https://your-domain.com/health`
- **Bot Server API:** `https://your-domain.com/bot-api` (if exposed)

## Next Steps

1. Update dashboard `app.js` to use public API URL
2. Test all endpoints from external network
3. Monitor logs for any issues
4. Setup monitoring/alerting
5. Configure backups


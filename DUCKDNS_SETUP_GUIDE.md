# DuckDNS Free Domain Setup Guide

Complete guide for setting up free domain with DuckDNS + SSL.

## What is DuckDNS?

- **Free** dynamic DNS service
- **Free** subdomain: `yourname.duckdns.org`
- **Easy** setup (2 minutes)
- **Auto-updates** IP address
- Works with **Let's Encrypt SSL** (free HTTPS)

## Quick Setup (Automated)

### Step 1: Get DuckDNS Account

1. Go to: **https://www.duckdns.org**
2. Sign in with:
   - Google
   - GitHub
   - Reddit
   - Twitter
3. Click **"Add Domain"**
4. Choose a subdomain (e.g., `myzoom`)
5. Copy your **token** from dashboard

### Step 2: Run Setup Script

```bash
# On your server
sudo ./setup-free-domain.sh
```

The script will ask for:
- DuckDNS subdomain (e.g., `myzoom`)
- DuckDNS token
- Your email (for SSL certificate)

### Step 3: Done!

After script completes:
- **Dashboard:** `https://myzoom.duckdns.org`
- **API:** `https://myzoom.duckdns.org/api`
- **SSL:** Automatically configured
- **Auto-update:** IP updates every 5 minutes

## Manual Setup

### Step 1: Update DuckDNS IP

```bash
# Get your server IP
SERVER_IP=$(curl -s ifconfig.me)

# Update DuckDNS (replace with your values)
curl "https://www.duckdns.org/update?domains=myzoom&token=YOUR_TOKEN&ip=${SERVER_IP}"
```

### Step 2: Install Nginx & Certbot

```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx
```

### Step 3: Create Nginx Config

Create `/etc/nginx/sites-available/zoom-bot-dashboard`:

```nginx
server {
    listen 80;
    server_name myzoom.duckdns.org;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name myzoom.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/myzoom.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myzoom.duckdns.org/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        if ($request_method = OPTIONS) {
            return 204;
        }
    }

    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
}
```

### Step 4: Enable Site

```bash
sudo ln -s /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Get SSL Certificate

```bash
sudo certbot --nginx -d myzoom.duckdns.org --email your-email@example.com --agree-tos
```

### Step 6: Setup Auto-Update

Create cron job to update DuckDNS IP:

```bash
# Edit crontab
sudo crontab -e

# Add this line (updates every 5 minutes)
*/5 * * * * curl -s "https://www.duckdns.org/update?domains=myzoom&token=YOUR_TOKEN&ip=" > /dev/null 2>&1
```

## Testing

### Check DNS

```bash
# Verify DNS is pointing to your server
dig +short myzoom.duckdns.org

# Should return your server's IP
```

### Test HTTPS

```bash
# Test from server
curl https://myzoom.duckdns.org/health

# Test from external network
curl https://myzoom.duckdns.org/health
```

### Test in Browser

Open: `https://myzoom.duckdns.org`

## Troubleshooting

### Issue: DNS Not Resolving

```bash
# Wait a few minutes for DNS propagation
# Check DNS
dig +short myzoom.duckdns.org

# Manually update DuckDNS
curl "https://www.duckdns.org/update?domains=myzoom&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"
```

### Issue: SSL Certificate Failed

```bash
# Make sure DNS is working first
dig +short myzoom.duckdns.org

# Try again
sudo certbot --nginx -d myzoom.duckdns.org

# Check nginx is running
sudo systemctl status nginx
```

### Issue: 502 Bad Gateway

```bash
# Check if Docker services are running
docker compose -f docker-compose.full.yml ps

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Test backend
curl http://localhost:3000/health
```

### Issue: DuckDNS IP Not Updating

```bash
# Test manual update
curl "https://www.duckdns.org/update?domains=myzoom&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"

# Check cron job
sudo crontab -l

# Check cron logs
sudo grep CRON /var/log/syslog
```

## Advantages of DuckDNS

✅ **Free** - No cost
✅ **Easy** - 2 minute setup
✅ **Reliable** - Good uptime
✅ **Auto-update** - IP changes automatically
✅ **SSL Compatible** - Works with Let's Encrypt
✅ **No Email Required** - Sign in with social accounts

## Security Notes

- DuckDNS domains are **public** (anyone can see your subdomain)
- Use **HTTPS** (SSL) for all traffic
- Consider adding **basic auth** for extra security
- Keep your **token** secret

## Alternative Free Domain Services

If DuckDNS doesn't work for you:

1. **No-IP** - https://www.noip.com
   - Free dynamic DNS
   - Requires email verification
   - More features (paid plans available)

2. **Freenom** - https://www.freenom.com
   - Free .tk, .ml, .ga domains
   - Full domain ownership
   - Requires more setup

3. **Cloudflare Tunnel** - https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
   - No port opening needed
   - Free SSL
   - More complex setup

## Next Steps

After setup:
1. ✅ Test dashboard: `https://myzoom.duckdns.org`
2. ✅ Test API: `https://myzoom.duckdns.org/api/health`
3. ✅ Bookmark your dashboard URL
4. ✅ Share with team (if needed)

Enjoy your free domain with SSL! 🎉


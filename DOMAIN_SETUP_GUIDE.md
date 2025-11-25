# 🌐 Domain Setup Guide: skylarkzoom.online

Complete guide to setup your purchased domain with SSL certificate.

## 📋 Prerequisites

1. ✅ Domain purchased: `skylarkzoom.online`
2. ✅ Server running with dashboard
3. ✅ Server's public IP address

## 🚀 Quick Setup (Automated)

Run this script on your server:

```bash
# Download and run
sudo ./setup-domain-skylarkzoom.sh
```

The script will:
- ✅ Guide you through DNS configuration
- ✅ Wait for DNS propagation
- ✅ Configure Nginx
- ✅ Install SSL certificate (Let's Encrypt)
- ✅ Setup auto-renewal

## 📝 Manual Setup Steps

### Step 1: Configure DNS Records

Go to your domain provider (Namecheap, GoDaddy, Cloudflare, etc.) and add:

#### A Record (Main Domain)
```
Type: A
Name: @ (or leave blank)
Value: YOUR_SERVER_IP
TTL: 3600
```

#### A Record (WWW)
```
Type: A
Name: www
Value: YOUR_SERVER_IP
TTL: 3600
```

**How to find your server IP:**
```bash
curl ifconfig.me
# or
hostname -I
```

### Step 2: Wait for DNS Propagation

DNS changes can take 5-30 minutes to propagate. Check with:

```bash
dig skylarkzoom.online @8.8.8.8
# Should show your server IP
```

### Step 3: Install Required Packages

```bash
sudo apt-get update
sudo apt-get install -y nginx certbot python3-certbot-nginx dnsutils
```

### Step 4: Configure Nginx

The script creates this config automatically at:
`/etc/nginx/sites-available/zoom-bot-dashboard`

**Manual config:**
```nginx
# HTTP - redirect to HTTPS
server {
    listen 80;
    server_name skylarkzoom.online www.skylarkzoom.online;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name skylarkzoom.online www.skylarkzoom.online;
    
    # SSL certificates (added by certbot)
    ssl_certificate /etc/letsencrypt/live/skylarkzoom.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/skylarkzoom.online/privkey.pem;
    
    # Dashboard
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API
    location /api {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
    }
    
    # Bot API
    location /bot-api {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Get SSL Certificate

```bash
sudo certbot --nginx \
    -d skylarkzoom.online \
    -d www.skylarkzoom.online \
    --email your-email@example.com \
    --agree-tos \
    --redirect
```

### Step 6: Setup Auto-Renewal

```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### Step 7: Configure Firewall

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow ssh
```

## 🔍 Verification

### Check DNS
```bash
dig skylarkzoom.online @8.8.8.8
dig www.skylarkzoom.online @8.8.8.8
```

### Check SSL
```bash
curl -I https://skylarkzoom.online
```

### Check Nginx
```bash
sudo nginx -t
sudo systemctl status nginx
```

## 🌐 Access Your Dashboard

After setup:
- **Dashboard:** https://skylarkzoom.online
- **API:** https://skylarkzoom.online/api
- **Bot API:** https://skylarkzoom.online/bot-api

## 🔧 Troubleshooting

### DNS Not Working
- Wait 30 minutes for propagation
- Check DNS records are correct
- Use `dig` to verify

### SSL Certificate Failed
- Ensure DNS is pointing to server
- Check port 80 is open
- Verify domain is accessible: `curl http://skylarkzoom.online`

### Nginx Errors
```bash
sudo nginx -t  # Test config
sudo tail -f /var/log/nginx/error.log  # Check errors
```

### Certificate Renewal
```bash
sudo certbot renew --dry-run  # Test renewal
sudo certbot renew  # Manual renewal
```

## 📞 Common Domain Providers

### Namecheap
1. Login: https://www.namecheap.com/myaccount/login/
2. Go to Domain List → Manage
3. Advanced DNS → Add A Record

### GoDaddy
1. Login: https://www.godaddy.com/
2. My Products → DNS
3. Add A Record

### Cloudflare
1. Login: https://dash.cloudflare.com/
2. Select domain → DNS
3. Add A Record

## ✅ Checklist

- [ ] DNS A records configured (@ and www)
- [ ] DNS propagated (checked with dig)
- [ ] Nginx installed and configured
- [ ] SSL certificate obtained
- [ ] Auto-renewal enabled
- [ ] Firewall configured (ports 80, 443)
- [ ] Dashboard accessible via HTTPS
- [ ] HTTP redirects to HTTPS

## 🎉 Done!

Your domain is now live with SSL! 🚀



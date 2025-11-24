# IP-Based Public Access Guide

Access dashboard publicly using server IP address (without domain).

## Method 1: Direct IP Access (HTTP Only)

### Step 1: Update Docker Compose to Expose Ports

Your `docker-compose.full.yml` already exposes ports, but ensure they're accessible:

```bash
# Check current port bindings
docker compose -f docker-compose.full.yml ps
```

### Step 2: Configure Firewall

```bash
# Allow ports through firewall
sudo ufw allow 8080/tcp  # Dashboard
sudo ufw allow 3000/tcp  # API
sudo ufw allow 3001/tcp  # Bot Server (optional)

# Check firewall status
sudo ufw status
```

### Step 3: Access Directly

- **Dashboard:** `http://YOUR_SERVER_IP:8080`
- **API:** `http://YOUR_SERVER_IP:3000`
- **Bot Server:** `http://YOUR_SERVER_IP:3001`

**Note:** HTTP only (no SSL). Not recommended for production with sensitive data.

---

## Method 2: Nginx with IP (Better Option)

### Step 1: Install Nginx

```bash
sudo apt update
sudo apt install nginx
```

### Step 2: Create Nginx Config for IP Access

Create `/etc/nginx/sites-available/zoom-bot-ip`:

```nginx
server {
    listen 80;
    server_name _;  # Accept any hostname/IP
    
    # Dashboard UI
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
        
        # CORS
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        if ($request_method = OPTIONS) {
            return 204;
        }
    }

    # Health Check
    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }

    # Bot Server API
    location /bot-api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 3: Enable and Test

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/zoom-bot-ip /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Step 4: Configure Firewall

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # For future SSL
```

### Step 5: Access

- **Dashboard:** `http://YOUR_SERVER_IP`
- **API:** `http://YOUR_SERVER_IP/api`
- **Health:** `http://YOUR_SERVER_IP/health`

---

## Method 3: Free Domain Services

### Option A: DuckDNS (Free, Easy)

1. **Sign up:** https://www.duckdns.org
2. **Create subdomain:** e.g., `myzoom.duckdns.org`
3. **Get token** from dashboard
4. **Update DNS:**

```bash
# Install DuckDNS updater
sudo apt install curl

# Update DNS (replace with your token and domain)
curl "https://www.duckdns.org/update?domains=myzoom&token=YOUR_TOKEN&ip="
```

5. **Use domain in Nginx config** (from PUBLIC_ACCESS_GUIDE.md)

### Option B: No-IP (Free Dynamic DNS)

1. **Sign up:** https://www.noip.com
2. **Create hostname:** e.g., `myzoom.ddns.net`
3. **Install No-IP client:**

```bash
cd /usr/local/src
wget https://www.noip.com/client/linux/noip-duc-linux.tar.gz
tar xzf noip-duc-linux.tar.gz
cd noip-2.1.9-1
make install
```

4. **Configure and use domain**

### Option C: Freenom (Free .tk, .ml, .ga domains)

1. **Sign up:** https://www.freenom.com
2. **Register free domain:** e.g., `myzoom.tk`
3. **Point DNS to server IP**
4. **Use in Nginx config**

---

## Quick Setup Script for IP Access

Run this on your server:

```bash
#!/bin/bash
# Quick IP-based access setup

set -e

echo "🌐 Setting up IP-based public access..."

# Install nginx
sudo apt update
sudo apt install -y nginx

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "Server IP: $SERVER_IP"

# Create nginx config
sudo tee /etc/nginx/sites-available/zoom-bot-ip > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;
    
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
        if ($request_method = OPTIONS) { return 204; }
    }

    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/zoom-bot-ip /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload
sudo nginx -t && sudo systemctl reload nginx

# Configure firewall
sudo ufw allow 80/tcp

echo ""
echo "✅ Setup complete!"
echo "📊 Dashboard: http://$SERVER_IP"
echo "🔌 API: http://$SERVER_IP/api"
echo "🏥 Health: http://$SERVER_IP/health"
```

---

## Security Considerations

### For IP Access (HTTP):

1. **Use VPN** for additional security
2. **Restrict by IP** in firewall (if you have static IPs)
3. **Add basic auth** in Nginx:

```nginx
location / {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    # ... rest of config
}
```

Create password file:
```bash
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

### For Free Domain (HTTPS):

1. Use Let's Encrypt SSL (free)
2. Follow `PUBLIC_ACCESS_GUIDE.md` for SSL setup
3. More secure than IP-only access

---

## Testing

### From External Network:

```bash
# Test dashboard
curl http://YOUR_SERVER_IP

# Test API
curl http://YOUR_SERVER_IP/api/health

# Test from browser
# Open: http://YOUR_SERVER_IP
```

### Check if Ports are Open:

```bash
# From external machine
telnet YOUR_SERVER_IP 80
# Or
nc -zv YOUR_SERVER_IP 80
```

---

## Troubleshooting

### Issue: Can't Access from External Network

1. **Check firewall:**
```bash
sudo ufw status
sudo iptables -L -n
```

2. **Check if service is listening:**
```bash
sudo netstat -tulpn | grep -E '80|8080|3000'
```

3. **Check cloud provider firewall:**
   - AWS: Security Groups
   - DigitalOcean: Firewall Rules
   - Google Cloud: Firewall Rules

### Issue: 502 Bad Gateway

```bash
# Check if services are running
docker compose -f docker-compose.full.yml ps

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Test backend
curl http://localhost:3000/health
```

---

## Recommendation

**Best Option:** Use free domain (DuckDNS) + SSL
- Free domain: `myzoom.duckdns.org`
- Free SSL: Let's Encrypt
- More professional
- Better security

**Quick Option:** Direct IP access
- Fastest setup
- No domain needed
- HTTP only (less secure)

Choose based on your needs!


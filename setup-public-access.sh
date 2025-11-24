#!/bin/bash
# Quick script to setup public access with Nginx and SSL

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🌐 Public Access Setup for Zoom Bot Dashboard${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Get domain name
read -p "Enter your domain name (e.g., dashboard.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Domain name is required${NC}"
    exit 1
fi

# Get email for Let's Encrypt
read -p "Enter your email for SSL certificate: " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ Email is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📦 Installing Nginx and Certbot...${NC}"
apt update
apt install -y nginx certbot python3-certbot-nginx

echo ""
echo -e "${YELLOW}📝 Creating Nginx configuration...${NC}"

# Create nginx config
cat > /etc/nginx/sites-available/zoom-bot-dashboard <<EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # Redirect all HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS Configuration
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};

    # SSL Certificate (will be added by certbot)
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
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
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # API Endpoints
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        # Handle preflight requests
        if (\$request_method = OPTIONS) {
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Logging
    access_log /var/log/nginx/zoom-dashboard-access.log;
    error_log /var/log/nginx/zoom-dashboard-error.log;
}
EOF

# Enable site
echo -e "${YELLOW}🔗 Enabling site...${NC}"
ln -sf /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
echo -e "${YELLOW}🧪 Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Nginx configuration is valid${NC}"
else
    echo -e "${RED}❌ Nginx configuration error${NC}"
    exit 1
fi

# Reload nginx
systemctl reload nginx

# Get SSL certificate
echo ""
echo -e "${YELLOW}🔒 Getting SSL certificate from Let's Encrypt...${NC}"
certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive

# Setup auto-renewal
echo -e "${YELLOW}🔄 Setting up SSL auto-renewal...${NC}"
systemctl enable certbot.timer
systemctl start certbot.timer

# Configure firewall
echo ""
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow ssh
    echo -e "${GREEN}✅ Firewall rules added${NC}"
else
    echo -e "${YELLOW}⚠️  UFW not found, please configure firewall manually${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Public access setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📊 Dashboard: https://${DOMAIN}${NC}"
echo -e "${GREEN}🔌 API: https://${DOMAIN}/api${NC}"
echo -e "${GREEN}🏥 Health: https://${DOMAIN}/health${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "  1. Update DNS A record for ${DOMAIN} to point to this server's IP"
echo "  2. Wait for DNS propagation (5-30 minutes)"
echo "  3. Test: curl https://${DOMAIN}/health"
echo "  4. Access dashboard: https://${DOMAIN}"
echo ""
echo -e "${YELLOW}💡 Note: Dashboard app.js already configured to use /api automatically${NC}"
echo ""


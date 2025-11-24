#!/bin/bash
# Setup free domain with DuckDNS + SSL (Let's Encrypt)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 Free Domain Setup (DuckDNS + SSL)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Get DuckDNS credentials
echo -e "${YELLOW}📝 Step 1: DuckDNS Setup${NC}"
echo ""
echo "1. Go to: https://www.duckdns.org"
echo "2. Sign in with Google/GitHub/Reddit"
echo "3. Create a subdomain (e.g., 'myzoom')"
echo "4. Copy your token from the dashboard"
echo ""
read -p "Enter your DuckDNS subdomain (e.g., myzoom): " DUCKDNS_SUBDOMAIN
read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
read -p "Enter your email (for SSL certificate): " EMAIL

if [ -z "$DUCKDNS_SUBDOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ All fields are required${NC}"
    exit 1
fi

DUCKDNS_DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
echo ""
echo -e "${GREEN}✅ Domain: ${DUCKDNS_DOMAIN}${NC}"
echo ""

# Step 2: Get current IP and update DuckDNS
echo -e "${YELLOW}📡 Step 2: Updating DuckDNS with current IP...${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    read -p "Enter your server's public IP address: " SERVER_IP
fi

echo -e "${BLUE}Server IP: ${SERVER_IP}${NC}"

# Update DuckDNS
UPDATE_URL="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${SERVER_IP}"
RESPONSE=$(curl -s "$UPDATE_URL")

if [ "$RESPONSE" = "OK" ]; then
    echo -e "${GREEN}✅ DuckDNS updated successfully${NC}"
else
    echo -e "${RED}❌ DuckDNS update failed. Response: ${RESPONSE}${NC}"
    echo "Please check your token and subdomain"
    exit 1
fi

# Wait for DNS propagation
echo ""
echo -e "${YELLOW}⏳ Waiting 30 seconds for DNS propagation...${NC}"
sleep 30

# Verify DNS
echo -e "${YELLOW}🔍 Verifying DNS...${NC}"
DNS_IP=$(dig +short ${DUCKDNS_DOMAIN} @8.8.8.8 | tail -1)

if [ "$DNS_IP" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✅ DNS is pointing to correct IP${NC}"
else
    echo -e "${YELLOW}⚠️  DNS might not be ready yet (IP: ${DNS_IP})${NC}"
    echo "Continuing anyway... DNS might take a few more minutes"
fi

echo ""

# Step 3: Install Nginx and Certbot
echo -e "${YELLOW}📦 Step 3: Installing Nginx and Certbot...${NC}"
apt update
apt install -y nginx certbot python3-certbot-nginx curl

# Step 4: Create Nginx configuration
echo -e "${YELLOW}📝 Step 4: Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/zoom-bot-dashboard <<EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ${DUCKDNS_DOMAIN} www.${DUCKDNS_DOMAIN};
    
    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other HTTP to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS Configuration (will be updated by certbot)
server {
    listen 443 ssl http2;
    server_name ${DUCKDNS_DOMAIN} www.${DUCKDNS_DOMAIN};

    # SSL Certificate (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DUCKDNS_DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DUCKDNS_DOMAIN}/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Dashboard UI
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
        
        # CORS
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        if (\$request_method = OPTIONS) {
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

# Step 5: Get SSL Certificate
echo ""
echo -e "${YELLOW}🔒 Step 5: Getting SSL certificate from Let's Encrypt...${NC}"
echo "This may take a minute..."
echo ""

certbot --nginx \
    -d ${DUCKDNS_DOMAIN} \
    -d www.${DUCKDNS_DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --redirect

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate installed successfully${NC}"
else
    echo -e "${RED}❌ SSL certificate installation failed${NC}"
    echo "This might be due to DNS not being ready yet."
    echo "Wait a few minutes and run: sudo certbot --nginx -d ${DUCKDNS_DOMAIN}"
    exit 1
fi

# Step 6: Setup auto-renewal
echo ""
echo -e "${YELLOW}🔄 Step 6: Setting up SSL auto-renewal...${NC}"
systemctl enable certbot.timer
systemctl start certbot.timer
echo -e "${GREEN}✅ Auto-renewal configured${NC}"

# Step 7: Setup DuckDNS auto-update (cron job)
echo ""
echo -e "${YELLOW}🔄 Step 7: Setting up DuckDNS auto-update...${NC}"
cat > /etc/cron.d/duckdns-update <<EOF
# Update DuckDNS every 5 minutes
*/5 * * * * root curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" > /dev/null 2>&1
EOF
chmod 644 /etc/cron.d/duckdns-update
echo -e "${GREEN}✅ DuckDNS auto-update configured (every 5 minutes)${NC}"

# Step 8: Configure firewall
echo ""
echo -e "${YELLOW}🔥 Step 8: Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo -e "${GREEN}✅ Firewall rules added${NC}"
else
    echo -e "${YELLOW}⚠️  UFW not found, please configure firewall manually${NC}"
fi

# Step 9: Check services
echo ""
echo -e "${YELLOW}🔍 Step 9: Checking Docker services...${NC}"
if docker ps | grep -q zoom-dashboard-api; then
    echo -e "${GREEN}✅ API service is running${NC}"
else
    echo -e "${YELLOW}⚠️  API service not running. Start it with:${NC}"
    echo "   docker compose -f docker-compose.full.yml up -d"
fi

if docker ps | grep -q zoom-dashboard-ui; then
    echo -e "${GREEN}✅ Dashboard UI is running${NC}"
else
    echo -e "${YELLOW}⚠️  Dashboard UI not running${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Free Domain Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🌐 Your Dashboard URLs:${NC}"
echo -e "   📊 Dashboard: ${BLUE}https://${DUCKDNS_DOMAIN}${NC}"
echo -e "   🔌 API: ${BLUE}https://${DUCKDNS_DOMAIN}/api${NC}"
echo -e "   🏥 Health: ${BLUE}https://${DUCKDNS_DOMAIN}/health${NC}"
echo ""
echo -e "${YELLOW}📝 Configuration Saved:${NC}"
echo -e "   Domain: ${DUCKDNS_DOMAIN}"
echo -e "   Token: ${DUCKDNS_TOKEN} (auto-updates every 5 min)"
echo -e "   SSL: Auto-renewing (Let's Encrypt)"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "   1. Wait 1-2 minutes for DNS to fully propagate"
echo "   2. Test: curl https://${DUCKDNS_DOMAIN}/health"
echo "   3. Open in browser: https://${DUCKDNS_DOMAIN}"
echo ""
echo -e "${YELLOW}🔒 Security Features:${NC}"
echo "   ✅ HTTPS/SSL enabled"
echo "   ✅ Auto-renewing SSL certificate"
echo "   ✅ DuckDNS auto-update (keeps IP current)"
echo "   ✅ Security headers configured"
echo ""


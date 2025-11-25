#!/bin/bash
# Complete domain setup for skylarkzoom.online
# This script configures DNS, Nginx, and SSL certificate

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="skylarkzoom.online"
EMAIL="sufyanmaviya400@gmail.com"  # Change this to your email

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌐 Domain Setup: ${DOMAIN}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Get server IP
echo -e "${YELLOW}📡 Step 1: Getting server IP address...${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    read -p "Enter your server's public IP address: " SERVER_IP
fi

echo -e "${GREEN}✅ Server IP: ${SERVER_IP}${NC}"
echo ""

# Step 2: DNS Configuration Instructions
echo -e "${YELLOW}📝 Step 2: DNS Configuration${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  IMPORTANT: Configure DNS records in your domain provider${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Go to your domain provider (where you bought ${DOMAIN})"
echo "Add these DNS records:"
echo ""
echo -e "${GREEN}Type: A Record${NC}"
echo -e "  Name: @ (or leave blank)"
echo -e "  Value: ${SERVER_IP}"
echo -e "  TTL: 3600 (or default)"
echo ""
echo -e "${GREEN}Type: A Record${NC}"
echo -e "  Name: www"
echo -e "  Value: ${SERVER_IP}"
echo -e "  TTL: 3600 (or default)"
echo ""
echo -e "${YELLOW}💡 Common domain providers:${NC}"
echo "  - Namecheap: https://www.namecheap.com/myaccount/login/"
echo "  - GoDaddy: https://www.godaddy.com/"
echo "  - Cloudflare: https://dash.cloudflare.com/"
echo "  - Google Domains: https://domains.google.com/"
echo ""
read -p "Press Enter after you've configured DNS records..."

# Step 3: Wait for DNS propagation
echo ""
echo -e "${YELLOW}⏳ Step 3: Waiting for DNS propagation...${NC}"
echo "This may take 5-30 minutes..."
echo ""

MAX_RETRIES=20
RETRY_COUNT=0
DNS_READY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 15
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${BLUE}Checking DNS... (Attempt $RETRY_COUNT/$MAX_RETRIES)${NC}"
    
    # Check multiple DNS servers
    DNS_IP1=$(dig +short ${DOMAIN} @8.8.8.8 2>/dev/null | tail -1)
    DNS_IP2=$(dig +short ${DOMAIN} @1.1.1.1 2>/dev/null | tail -1)
    DNS_IP3=$(dig +short www.${DOMAIN} @8.8.8.8 2>/dev/null | tail -1)
    
    if [ "$DNS_IP1" = "$SERVER_IP" ] || [ "$DNS_IP2" = "$SERVER_IP" ] || [ "$DNS_IP3" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✅ DNS is pointing to correct IP (${SERVER_IP})${NC}"
        DNS_READY=true
        break
    else
        echo -e "${YELLOW}   DNS not ready yet... (found: ${DNS_IP1:-none})${NC}"
    fi
done

if [ "$DNS_READY" = false ]; then
    echo -e "${RED}❌ DNS propagation taking too long${NC}"
    echo "You can continue, but SSL certificate might fail"
    echo "You can run this script again later"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

# Step 4: Install required packages
echo ""
echo -e "${YELLOW}📦 Step 4: Installing required packages...${NC}"

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "Installing Nginx..."
    apt-get update
    apt-get install -y nginx
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Check if dig is installed
if ! command -v dig &> /dev/null; then
    apt-get install -y dnsutils
fi

echo -e "${GREEN}✅ Packages installed${NC}"

# Step 5: Configure Nginx
echo ""
echo -e "${YELLOW}⚙️  Step 5: Configuring Nginx...${NC}"

# Create nginx config for domain
cat > /etc/nginx/sites-available/zoom-bot-dashboard << EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} www.${DOMAIN};

    # SSL will be configured by certbot
    # These will be added automatically:
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # Dashboard (React app)
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

    # API Server
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # CORS headers
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        
        if (\$request_method = OPTIONS) {
            return 204;
        }
    }

    # Health check
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
echo "Enabling site..."
ln -sf /etc/nginx/sites-available/zoom-bot-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
echo "Testing Nginx configuration..."
if nginx -t; then
    echo -e "${GREEN}✅ Nginx configuration is valid${NC}"
else
    echo -e "${RED}❌ Nginx configuration error${NC}"
    exit 1
fi

# Reload nginx
systemctl reload nginx
echo -e "${GREEN}✅ Nginx configured and reloaded${NC}"

# Step 6: Get SSL Certificate
echo ""
echo -e "${YELLOW}🔒 Step 6: Getting SSL certificate from Let's Encrypt...${NC}"
echo "This may take a minute..."
echo ""

# Verify domain is accessible
echo "Verifying domain is accessible..."
HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://${DOMAIN} 2>/dev/null || echo "000")

if [ "$HTTP_TEST" = "301" ] || [ "$HTTP_TEST" = "200" ]; then
    echo -e "${GREEN}✅ Domain is accessible (HTTP ${HTTP_TEST})${NC}"
else
    echo -e "${YELLOW}⚠️  Domain might not be fully accessible (HTTP ${HTTP_TEST})${NC}"
    echo "Continuing anyway..."
fi

echo ""

# Try nginx mode first (recommended)
echo "Attempting SSL certificate with nginx mode..."
certbot --nginx \
    -d ${DOMAIN} \
    -d www.${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --redirect \
    --no-eff-email \
    --quiet

SSL_SUCCESS=$?

if [ $SSL_SUCCESS -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate installed successfully${NC}"
    echo -e "${GREEN}✅ Nginx config automatically updated with SSL${NC}"
else
    echo -e "${YELLOW}⚠️  Nginx mode failed, trying standalone mode...${NC}"
    
    # Stop nginx temporarily
    systemctl stop nginx
    sleep 2
    
    # Try standalone mode
    certbot certonly --standalone \
        -d ${DOMAIN} \
        -d www.${DOMAIN} \
        --email ${EMAIL} \
        --agree-tos \
        --non-interactive \
        --no-eff-email \
        --preferred-challenges http
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Certificate obtained via standalone mode${NC}"
        
        # Restart nginx
        systemctl start nginx
        sleep 2
        
        # Configure nginx with SSL
        certbot --nginx \
            -d ${DOMAIN} \
            -d www.${DOMAIN} \
            --email ${EMAIL} \
            --agree-tos \
            --non-interactive \
            --redirect \
            --no-eff-email
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ SSL configured successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Certificate obtained but nginx config update failed${NC}"
            systemctl start nginx
        fi
    else
        echo -e "${RED}❌ SSL certificate installation failed${NC}"
        systemctl start nginx
        echo ""
        echo "Common issues:"
        echo "  1. DNS not fully propagated - wait 30 minutes and try again"
        echo "  2. Port 80 blocked - check firewall"
        echo "  3. Domain not accessible - check DNS records"
        exit 1
    fi
fi

# Step 7: Setup SSL Auto-Renewal
echo ""
echo -e "${YELLOW}🔄 Step 7: Setting up SSL auto-renewal...${NC}"
systemctl enable certbot.timer
systemctl start certbot.timer
echo -e "${GREEN}✅ SSL auto-renewal configured${NC}"

# Step 8: Configure Firewall
echo ""
echo -e "${YELLOW}🔥 Step 8: Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow ssh
    echo -e "${GREEN}✅ Firewall rules added${NC}"
else
    echo -e "${YELLOW}⚠️  UFW not found, please configure firewall manually${NC}"
fi

# Final Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅✅ Domain setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🌐 Your dashboard is now available at:${NC}"
echo -e "   ${BLUE}https://${DOMAIN}${NC}"
echo -e "   ${BLUE}https://www.${DOMAIN}${NC}"
echo ""
echo -e "${GREEN}📊 API endpoints:${NC}"
echo -e "   ${BLUE}https://${DOMAIN}/api${NC}"
echo -e "   ${BLUE}https://${DOMAIN}/bot-api${NC}"
echo ""
echo -e "${GREEN}✅ SSL certificate: Installed and auto-renewing${NC}"
echo -e "${GREEN}✅ HTTP to HTTPS: Automatic redirect${NC}"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "   1. Test your dashboard: https://${DOMAIN}"
echo "   2. SSL will auto-renew (no action needed)"
echo "   3. If you change server IP, update DNS A records"
echo ""


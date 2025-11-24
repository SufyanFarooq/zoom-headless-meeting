#!/bin/bash
# Quick IP-based public access setup (no domain required)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🌐 Setting up IP-based public access...${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Get server IP
echo -e "${YELLOW}📡 Detecting server IP...${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    read -p "Enter your server's public IP address: " SERVER_IP
fi
echo -e "${GREEN}✅ Server IP: ${SERVER_IP}${NC}"
echo ""

# Install nginx
echo -e "${YELLOW}📦 Installing Nginx...${NC}"
apt update
apt install -y nginx

# Create nginx config
echo -e "${YELLOW}📝 Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/zoom-bot-ip <<'EOF'
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

    # Logging
    access_log /var/log/nginx/zoom-dashboard-access.log;
    error_log /var/log/nginx/zoom-dashboard-error.log;
}
EOF

# Enable site
echo -e "${YELLOW}🔗 Enabling site...${NC}"
ln -sf /etc/nginx/sites-available/zoom-bot-ip /etc/nginx/sites-enabled/
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

# Configure firewall
echo ""
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    echo -e "${GREEN}✅ Firewall rule added for port 80${NC}"
else
    echo -e "${YELLOW}⚠️  UFW not found, please configure firewall manually${NC}"
fi

# Check if services are running
echo ""
echo -e "${YELLOW}🔍 Checking Docker services...${NC}"
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

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ IP-based access setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📊 Dashboard: http://${SERVER_IP}${NC}"
echo -e "${GREEN}🔌 API: http://${SERVER_IP}/api${NC}"
echo -e "${GREEN}🏥 Health: http://${SERVER_IP}/health${NC}"
echo ""
echo -e "${YELLOW}📝 Important Notes:${NC}"
echo "  ⚠️  This is HTTP only (no SSL/HTTPS)"
echo "  ⚠️  Less secure than HTTPS"
echo "  💡 For better security, use free domain + SSL"
echo "  💡 See IP_ACCESS_GUIDE.md for free domain options"
echo ""
echo -e "${YELLOW}🔒 Optional: Add Basic Auth Protection${NC}"
echo "  Run: sudo htpasswd -c /etc/nginx/.htpasswd admin"
echo "  Then add auth_basic to nginx config"
echo ""
echo -e "${YELLOW}🌍 Test from external network:${NC}"
echo "  curl http://${SERVER_IP}/health"
echo ""


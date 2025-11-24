#!/bin/bash
# Fix SSL DNS CAA issue

DOMAIN="zbot.duckdns.org"
EMAIL="sufyanmaviya400@gmail.com"

echo "🔧 Fixing SSL installation for ${DOMAIN}..."
echo ""

# Check current DNS
echo "🔍 Checking DNS records..."
dig ${DOMAIN} +short
echo ""

# Stop nginx to free port 80
echo "🛑 Stopping nginx..."
systemctl stop nginx
sleep 3

# Verify port 80 is free
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 80 still in use, killing process..."
    fuser -k 80/tcp
    sleep 2
fi

# Try standalone with verbose output
echo "🔒 Attempting SSL certificate installation..."
echo ""

certbot certonly --standalone \
    -d ${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --no-eff-email \
    --preferred-challenges http \
    --verbose 2>&1 | tee /tmp/certbot-output.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Certificate obtained!"
    
    # Start nginx
    systemctl start nginx
    sleep 2
    
    # Configure nginx with SSL
    echo "📝 Configuring nginx with SSL..."
    certbot --nginx \
        -d ${DOMAIN} \
        --email ${EMAIL} \
        --agree-tos \
        --non-interactive \
        --redirect \
        --no-eff-email
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅✅ SSL successfully installed and configured!"
        echo ""
        echo "🌐 Access your site:"
        echo "   https://${DOMAIN}"
        echo ""
        echo "🔒 SSL auto-renewal is already configured"
    else
        echo "⚠️  Certificate obtained but nginx config failed"
        systemctl start nginx
    fi
else
    echo ""
    echo "❌ Certificate installation failed"
    echo ""
    echo "📋 Check the log:"
    echo "   cat /tmp/certbot-output.log"
    echo ""
    echo "💡 Possible solutions:"
    echo "   1. Wait 10-15 minutes for DNS propagation"
    echo "   2. Check if domain is accessible: curl http://${DOMAIN}"
    echo "   3. Verify firewall allows port 80: sudo ufw allow 80/tcp"
    echo ""
    
    # Restart nginx anyway
    systemctl start nginx
    exit 1
fi

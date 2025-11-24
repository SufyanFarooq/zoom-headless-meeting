#!/bin/bash
# Manual SSL installation script

set -e

DOMAIN="zbot.duckdns.org"
EMAIL="sufyanmaviya400@gmail.com"

echo "🔒 Installing SSL certificate for ${DOMAIN}..."
echo ""

# Check if domain is accessible
echo "🔍 Checking domain accessibility..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://${DOMAIN} || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Domain is accessible via HTTP"
else
    echo "⚠️  Domain might not be fully accessible (HTTP ${HTTP_CODE})"
fi
echo ""

# Method 1: Try standalone mode first (more reliable for DNS issues)
echo "📦 Method 1: Trying standalone mode (stops nginx temporarily)..."
systemctl stop nginx

# Wait a moment
sleep 2

# Check if port 80 is free
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 80 is still in use, waiting..."
    sleep 5
fi

certbot certonly --standalone \
    -d ${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --no-eff-email \
    --preferred-challenges http \
    --verbose

STANDALONE_RESULT=$?

# Restart nginx
systemctl start nginx
sleep 2

if [ $STANDALONE_RESULT -eq 0 ]; then
    echo "✅ Certificate obtained via standalone mode!"
    echo ""
    echo "📝 Now configuring nginx with SSL..."
    
    # Update nginx config with SSL
    certbot --nginx \
        -d ${DOMAIN} \
        --email ${EMAIL} \
        --agree-tos \
        --non-interactive \
        --redirect \
        --no-eff-email
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅✅ SSL installed and configured successfully!"
        echo ""
        echo "🌐 Your site is now available at:"
        echo "   https://${DOMAIN}"
        exit 0
    else
        echo "⚠️  Certificate obtained but nginx config update failed"
        echo "You may need to manually configure SSL in nginx"
    fi
else
    echo ""
    echo "❌ Standalone mode failed, trying DNS challenge..."
    echo ""
    
    # Method 2: Try DNS challenge (manual)
    echo "📋 Method 2: DNS Challenge (Manual)"
    echo ""
    echo "This requires manual DNS TXT record setup."
    echo "Run this command and follow the instructions:"
    echo ""
    echo "  certbot certonly --manual --preferred-challenges dns \\"
    echo "    -d ${DOMAIN} --email ${EMAIL} --agree-tos"
    echo ""
    echo "Or try again later - DNS might need more time to propagate."
    echo ""
    
    # Method 3: Try nginx mode as last resort
    echo "📦 Method 3: Trying nginx mode one more time..."
    certbot --nginx \
        -d ${DOMAIN} \
        --email ${EMAIL} \
        --agree-tos \
        --non-interactive \
        --redirect \
        --no-eff-email \
        --force-renewal
    
    if [ $? -eq 0 ]; then
        echo "✅ SSL installed via nginx mode!"
        exit 0
    else
        echo ""
        echo "❌ All methods failed"
        echo ""
        echo "🔍 Troubleshooting steps:"
        echo "  1. Wait 10-15 minutes for DNS to fully propagate"
        echo "  2. Check DNS: dig ${DOMAIN}"
        echo "  3. Verify port 80 is accessible from internet"
        echo "  4. Try again: sudo certbot --nginx -d ${DOMAIN}"
        echo ""
        echo "💡 For now, site is accessible via HTTP:"
        echo "   http://${DOMAIN}"
        exit 1
    fi
fi

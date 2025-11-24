#!/bin/bash
# Manual SSL installation script

set -e

DOMAIN="zbot.duckdns.org"
EMAIL="sufyanmaviya400@gmail.com"

echo "🔒 Installing SSL certificate for ${DOMAIN}..."

# Method 1: Try nginx mode
echo "Attempting nginx mode..."
certbot --nginx -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --redirect

if [ $? -eq 0 ]; then
    echo "✅ SSL installed successfully!"
    exit 0
fi

# Method 2: Try standalone mode
echo ""
echo "Nginx mode failed, trying standalone mode..."
systemctl stop nginx
certbot certonly --standalone -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --preferred-challenges http
systemctl start nginx

if [ $? -eq 0 ]; then
    echo "✅ Certificate obtained, updating nginx..."
    certbot --nginx -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --redirect
    echo "✅ SSL installed successfully!"
else
    echo "❌ SSL installation failed"
    echo ""
    echo "Check:"
    echo "  1. DNS is propagated: dig ${DOMAIN}"
    echo "  2. Port 80 is open: sudo ufw allow 80/tcp"
    echo "  3. Domain is accessible: curl http://${DOMAIN}"
    exit 1
fi

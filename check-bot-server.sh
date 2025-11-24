#!/bin/bash
# Check bot server status and fix connection

echo "🔍 Checking bot server status..."
echo ""

# Check if bot server container is running
echo "1. Checking Docker containers:"
docker ps | grep -E "bot-server|zoom-bot-server" || echo "   ❌ Bot server container not running"

echo ""
echo "2. Checking if port 3001 is listening:"
sudo netstat -tulpn | grep :3001 || echo "   ❌ Port 3001 not listening"

echo ""
echo "3. Testing bot server API:"
curl -s http://localhost:3001/health || echo "   ❌ Bot server not responding"

echo ""
echo "4. Testing with 127.0.0.1:"
curl -s http://127.0.0.1:3001/health || echo "   ❌ Bot server not responding on 127.0.0.1"

echo ""
echo "✅ Check complete!"

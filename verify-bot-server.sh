#!/bin/bash
# Verify bot server is working

echo "🔍 Verifying Bot Server Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CONTAINER_NAME="zoom-bot-server-api"

# 1. Check container exists and is running
echo "1️⃣ Container Status:"
if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "   ✅ Container exists: $CONTAINER_NAME"
    STATUS=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
    echo "   📊 Status: $STATUS"
else
    echo "   ❌ Container not found!"
    exit 1
fi
echo ""

# 2. Check container logs
echo "2️⃣ Container Logs (last 10 lines):"
docker logs $CONTAINER_NAME --tail 10 2>&1
echo ""

# 3. Check API health
echo "3️⃣ API Health Check:"
if curl -s -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "   ✅ API is responding"
    RESPONSE=$(curl -s http://localhost:3001/health)
    echo "   Response: $RESPONSE"
else
    echo "   ⚠️  API not responding (might still be starting)"
    echo "   Trying again in 2 seconds..."
    sleep 2
    if curl -s -f http://localhost:3001/health > /dev/null 2>&1; then
        echo "   ✅ API is now responding"
    else
        echo "   ❌ API still not responding"
        echo "   Check logs: docker logs $CONTAINER_NAME"
    fi
fi
echo ""

# 4. Check port
echo "4️⃣ Port Check:"
PORTS=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Ports}}")
echo "   Ports: $PORTS"
echo ""

# 5. Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Container Status: RUNNING"
echo "✅ Container Name: $CONTAINER_NAME"
echo "✅ Port: 3001"
echo ""
echo "💡 To check logs: docker logs $CONTAINER_NAME"
echo "💡 To restart: docker-compose -f docker-compose.full.yml restart bot-server"

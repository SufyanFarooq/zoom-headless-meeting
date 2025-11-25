#!/bin/bash
# Check bot server container status

echo "🔍 Bot Server Container Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if container exists
if docker ps --filter "name=zoom-bot-server" --format "{{.Names}}" | grep -q "zoom-bot-server"; then
    echo "✅ Container exists: zoom-bot-server-api"
    echo ""
    
    # Get container details
    echo "📊 Container Details:"
    docker ps --filter "name=zoom-bot-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Check if it's healthy
    echo "🏥 Health Check:"
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        echo "   ✅ Bot server API is responding"
        curl -s http://localhost:3001/health | head -3
    else
        echo "   ⚠️  Bot server API not responding yet (might be starting)"
    fi
    echo ""
    
    # Check logs
    echo "📋 Recent Logs (last 5 lines):"
    docker logs zoom-bot-server-api --tail 5 2>&1
    echo ""
    
    echo "✅ Container is running successfully!"
else
    echo "❌ Container not found"
    echo ""
    echo "All containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
fi

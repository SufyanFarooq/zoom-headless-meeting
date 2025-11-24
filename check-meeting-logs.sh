#!/bin/bash
# Check logs for meeting creation

echo "📋 Meeting Creation Logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check API logs
echo "🔍 API Container Logs (last 50 lines):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker logs zoom-dashboard-api --tail 50 2>&1 | grep -E "createBots|meeting|bot|error|Error|✅|❌" || docker logs zoom-dashboard-api --tail 50
echo ""

# Check Bot Server logs
echo "🔍 Bot Server Container Logs (last 50 lines):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker logs zoom-bot-server-api --tail 50 2>&1 | grep -E "create|bot|error|Error|✅|❌" || docker logs zoom-bot-server-api --tail 50
echo ""

# Check for bot containers
echo "🔍 Bot Containers Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "No bot containers found"
echo ""

# Check recent bot container logs
echo "🔍 Recent Bot Container Logs (first 3 bots, last 20 lines each):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BOT_CONTAINERS=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" | head -3)
if [ -z "$BOT_CONTAINERS" ]; then
    echo "No bot containers running"
else
    for container in $BOT_CONTAINERS; do
        echo "📦 $container:"
        docker logs "$container" --tail 20 2>&1 | head -20
        echo ""
    done
fi

echo ""
echo "✅ Log check complete!"
echo ""
echo "💡 To see live logs:"
echo "   docker logs -f zoom-dashboard-api"
echo "   docker logs -f zoom-bot-server-api"
echo "   docker logs -f zoom-bot-1"

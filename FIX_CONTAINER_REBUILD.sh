#!/bin/bash
# Fix Container Rebuild - Server 1
# This script properly rebuilds the main API container

set -e

echo "🔍 Step 1: Checking server code..."
if grep -q "priority = 1" api/services/botService.js; then
    echo "✅ Server code has priority logic"
else
    echo "❌ Server code missing priority logic!"
    echo "   Run: git pull origin main"
    exit 1
fi

echo ""
echo "🛑 Step 2: Stopping and removing container..."
docker stop zoom-dashboard-api 2>/dev/null || echo "   Container not running"
docker rm zoom-dashboard-api 2>/dev/null || echo "   Container not found"

echo ""
echo "🗑️  Step 3: Removing old image..."
# Get image name from docker-compose
IMAGE_NAME=$(docker compose -f docker-compose.full.yml config | grep -A 5 "api:" | grep "image:" | awk '{print $2}' || echo "")
if [ -z "$IMAGE_NAME" ]; then
    # If no image name, try to find it from container history
    IMAGE_NAME=$(docker images | grep -E "meetingsdk|zoom.*api|api.*zoom" | head -1 | awk '{print $1":"$2}' || echo "")
fi

if [ -n "$IMAGE_NAME" ]; then
    echo "   Removing image: $IMAGE_NAME"
    docker rmi "$IMAGE_NAME" 2>/dev/null || echo "   Image not found (will be rebuilt)"
else
    echo "   No image name found (will be rebuilt)"
fi

# Also remove by container name pattern
docker images | grep -E "meetingsdk.*api|api.*meetingsdk" | awk '{print $3}' | xargs -r docker rmi 2>/dev/null || true

echo ""
echo "🔨 Step 4: Rebuilding container (NO CACHE)..."
docker compose -f docker-compose.full.yml build --no-cache api

echo ""
echo "🚀 Step 5: Starting container..."
docker compose -f docker-compose.full.yml up -d api

echo ""
echo "⏳ Step 6: Waiting for container to start..."
sleep 5

echo ""
echo "✅ Step 7: Verifying container code..."
if docker exec zoom-dashboard-api grep -q "priority = 1" /app/api/services/botService.js 2>/dev/null; then
    echo "✅ Container has priority logic!"
    docker exec zoom-dashboard-api grep -n "priority = 1" /app/api/services/botService.js
else
    echo "❌ Container still missing priority logic!"
    echo "   Checking what's in the file..."
    docker exec zoom-dashboard-api head -60 /app/api/services/botService.js | tail -20
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Rebuild complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next steps:"
echo "   1. Test meeting creation"
echo "   2. Check logs: docker logs zoom-dashboard-api --tail 50"
echo "   3. Look for: '✅ Selected Server 1' in logs"
echo ""


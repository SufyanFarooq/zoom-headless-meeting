#!/bin/bash

# Script to stop all running bot containers
# Use this when containers are stuck and not stopping via API

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛑 Stop All Bot Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get running bot containers
echo "📋 Finding running bot containers..."
RUNNING_CONTAINERS=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null || echo "")

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "✅ No running bot containers found"
    exit 0
fi

CONTAINER_COUNT=$(echo "$RUNNING_CONTAINERS" | wc -l | tr -d ' ')
echo "Found $CONTAINER_COUNT running containers"
echo ""

# Show containers
echo "Running containers:"
echo "$RUNNING_CONTAINERS" | head -20
if [ "$CONTAINER_COUNT" -gt 20 ]; then
    echo "... and $((CONTAINER_COUNT - 20)) more"
fi
echo ""

# Confirm
read -p "Stop all $CONTAINER_COUNT containers? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "🛑 Stopping containers..."

# Stop containers in batches
BATCH_SIZE=20
CONTAINER_ARRAY=($RUNNING_CONTAINERS)
TOTAL=${#CONTAINER_ARRAY[@]}
STOPPED=0
FAILED=0

for ((i=0; i<$TOTAL; i+=$BATCH_SIZE)); do
    BATCH=("${CONTAINER_ARRAY[@]:$i:$BATCH_SIZE}")
    
    echo "Stopping batch $((i/BATCH_SIZE + 1)) ($(($i + 1))-$((i + ${#BATCH[@]})) of $TOTAL)..."
    
    for container in "${BATCH[@]}"; do
        if docker stop "$container" > /dev/null 2>&1; then
            STOPPED=$((STOPPED + 1))
        else
            FAILED=$((FAILED + 1))
            echo "  ⚠️  Failed to stop: $container"
        fi
    done
    
    # Small delay between batches
    sleep 1
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Stopped: $STOPPED containers"
if [ $FAILED -gt 0 ]; then
    echo "Failed: $FAILED containers"
fi
echo ""

# Verify
REMAINING=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
    echo "⚠️  Warning: $REMAINING containers still running"
    echo "   Try force stop:"
    echo "   docker stop \$(docker ps --filter 'name=zoom-bot' -q)"
else
    echo "✅ All containers stopped"
fi
echo ""

# Update database load (if database accessible)
if docker ps | grep -q zoom-dashboard-db; then
    echo "📊 Updating database load..."
    docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots << EOF
-- Reset all server loads to 0
UPDATE bot_servers SET current_load = 0 WHERE current_load > 0;
SELECT server_name, capacity, current_load FROM bot_servers;
EOF
    echo "✅ Database updated"
fi

echo ""
echo "💡 Next Steps:"
echo "   1. Check dashboard - meetings should show as stopped"
echo "   2. Verify containers: docker ps | grep zoom-bot"
echo "   3. If still running, force stop: docker stop \$(docker ps --filter 'name=zoom-bot' -q)"
echo ""


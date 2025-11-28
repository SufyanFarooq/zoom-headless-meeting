#!/bin/bash

# Complete fix for stuck containers
# Stops containers and updates database

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Fix Stuck Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Stop all running bot containers
echo "📋 Step 1: Stopping all bot containers..."
RUNNING=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

if [ "$RUNNING" -gt 0 ]; then
    echo "Found $RUNNING running containers"
    echo ""
    
    # Stop all containers
    docker stop $(docker ps --filter "name=zoom-bot" -q) 2>/dev/null || true
    
    # Wait a bit
    sleep 2
    
    # Force stop if still running
    STILL_RUNNING=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$STILL_RUNNING" -gt 0 ]; then
        echo "Force stopping remaining containers..."
        docker kill $(docker ps --filter "name=zoom-bot" -q) 2>/dev/null || true
    fi
    
    echo "✅ Containers stopped"
else
    echo "✅ No running containers"
fi
echo ""

# Step 2: Remove stopped containers (optional)
read -p "Remove stopped containers? (y/n): " REMOVE
if [ "$REMOVE" = "y" ]; then
    echo "Removing stopped containers..."
    docker rm $(docker ps -a --filter "name=zoom-bot" --filter "status=exited" -q) 2>/dev/null || true
    echo "✅ Removed"
fi
echo ""

# Step 3: Update database
if docker ps | grep -q zoom-dashboard-db; then
    echo "📋 Step 2: Updating database..."
    
    # Get actual running containers count
    ACTUAL_RUNNING=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
    
    echo "Actual running containers: $ACTUAL_RUNNING"
    echo ""
    
    # Update server loads
    docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots << EOF
-- Reset Server 1 load
UPDATE bot_servers 
SET current_load = $ACTUAL_RUNNING 
WHERE server_name = 'server-1';

-- Reset Server 2 load (if exists)
UPDATE bot_servers 
SET current_load = 0 
WHERE server_name = 'server-2';

-- Show updated status
SELECT server_name, capacity, current_load, (capacity - current_load) as available 
FROM bot_servers 
ORDER BY priority;
EOF
    
    echo ""
    echo "✅ Database updated"
else
    echo "⚠️  Database container not found, skipping database update"
fi
echo ""

# Step 4: Verify
echo "📋 Step 3: Verification..."
echo ""
echo "Running containers:"
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}" | head -10
TOTAL_RUNNING=$(docker ps --filter "name=zoom-bot" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Total running: $TOTAL_RUNNING"
echo ""

# Step 5: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fix Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Status:"
echo "   Running containers: $TOTAL_RUNNING"
echo "   Database updated: ✅"
echo ""
echo "💡 If containers still running:"
echo "   docker kill \$(docker ps --filter 'name=zoom-bot' -q)"
echo ""


#!/bin/bash
# Stop all failing bot containers

echo "🛑 Stopping all bot containers..."
echo ""

# Stop and remove all zoom-bot containers
docker ps -a --filter "name=zoom-bot" --format "{{.Names}}" | while read container; do
    echo "Stopping: $container"
    docker stop "$container" 2>/dev/null
    docker rm -f "$container" 2>/dev/null
done

echo ""
echo "✅ All bot containers stopped and removed"
echo ""
echo "📋 Remaining containers:"
docker ps --format "table {{.Names}}\t{{.Status}}"

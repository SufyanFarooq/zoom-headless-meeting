#!/bin/bash
# Clean up all bot containers

echo "🧹 Cleaning up all bot containers..."
echo ""

# Stop and remove all zoom-bot containers
CONTAINERS=$(docker ps -a --filter "name=zoom-bot" --format "{{.Names}}")
if [ -z "$CONTAINERS" ]; then
    echo "No bot containers found"
else
    echo "Found containers:"
    echo "$CONTAINERS"
    echo ""
    echo "Removing..."
    docker ps -a --filter "name=zoom-bot" --format "{{.Names}}" | xargs -r docker rm -f
    echo "✅ Removed all bot containers"
fi

echo ""
echo "📋 Remaining containers:"
docker ps --format "table {{.Names}}\t{{.Status}}"

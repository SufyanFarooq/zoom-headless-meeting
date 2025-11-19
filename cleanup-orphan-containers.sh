#!/bin/bash

# Script to clean up orphan containers from compose file

echo "🧹 Cleaning Up Orphan Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Stop and remove orphan containers
echo "📋 Stopping orphan containers..."
docker compose -f compose-50-bots.yaml down --remove-orphans 2>/dev/null || true

echo ""
echo "🗑️  Removing orphan containers..."
docker ps -a --filter "name=zoom-bot-" --format "{{.Names}}" | \
  grep -E "zoom-bot-(1[1-9]|[2-9][0-9]|100)$" | \
  xargs -r docker rm -f 2>/dev/null || true

echo ""
echo "✅ Orphan containers cleaned up!"
echo ""
echo "💡 To prevent this warning in future:"
echo "   docker compose -f compose-50-bots.yaml down --remove-orphans"


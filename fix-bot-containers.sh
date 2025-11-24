#!/bin/bash
# Fix bot containers - clean up and check paths

echo "🧹 Cleaning up orphan bot containers..."
echo ""

# Stop and remove all zoom-bot containers
docker ps -a --filter "name=zoom-bot" --format "{{.Names}}" | xargs -r docker rm -f

echo "✅ Cleaned up bot containers"
echo ""

# Check if entry script exists in the mounted volume
echo "🔍 Checking entry script path..."
if [ -f "/opt/zoom-headless-meeting/bin/entry-bot-optimized.sh" ]; then
    echo "✅ Entry script found at: /opt/zoom-headless-meeting/bin/entry-bot-optimized.sh"
    ls -lh /opt/zoom-headless-meeting/bin/entry-bot-optimized.sh
elif [ -f "./bin/entry-bot-optimized.sh" ]; then
    echo "✅ Entry script found at: ./bin/entry-bot-optimized.sh"
    ls -lh ./bin/entry-bot-optimized.sh
else
    echo "❌ Entry script not found!"
    echo "Looking for entry scripts:"
    find . -name "entry*.sh" -type f 2>/dev/null | head -5
fi

echo ""
echo "📋 Current compose file entrypoint:"
grep -A 3 "entrypoint:" compose-50-bots.yaml | head -5

echo ""
echo "✅ Cleanup complete!"

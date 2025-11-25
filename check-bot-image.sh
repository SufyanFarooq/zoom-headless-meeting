#!/bin/bash
# Check if zoom-bot image exists and build if needed

echo "🔍 Checking zoom-bot:latest image..."
echo ""

# Check if image exists
if docker images zoom-bot:latest --format "{{.Repository}}:{{.Tag}}" | grep -q "zoom-bot:latest"; then
    echo "✅ zoom-bot:latest image exists"
    docker images zoom-bot:latest
    echo ""
    echo "Image size and details:"
    docker images zoom-bot:latest --format "Size: {{.Size}}, Created: {{.CreatedAt}}"
else
    echo "❌ zoom-bot:latest image NOT found"
    echo ""
    echo "⚠️  This is why containers are trying to build from source!"
    echo ""
    echo "📋 To build the image (takes 10-30 minutes):"
    echo "   docker build -t zoom-bot:latest ."
    echo ""
    echo "💡 Build time depends on:"
    echo "   - Server CPU (2-4 cores: 20-30 min, 8+ cores: 10-15 min)"
    echo "   - RAM (4GB: slower, 8GB+: faster)"
    echo "   - Disk speed (SSD: faster, HDD: slower)"
fi

echo ""
echo "📊 Current bot containers status:"
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

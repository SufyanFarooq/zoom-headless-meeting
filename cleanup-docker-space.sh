#!/bin/bash

# Script to clean up Docker and free disk space on server
# Run this when you get "no space left on device" errors

set -e

echo "🧹 Docker Cleanup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check disk space
echo "📊 Current Disk Usage:"
df -h / | tail -1
echo ""

# Check Docker disk usage
echo "🐳 Docker Disk Usage:"
docker system df 2>/dev/null || echo "Docker not running or not accessible"
echo ""

# Ask for confirmation
read -p "Continue with cleanup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🧹 Starting cleanup..."
echo ""

# 1. Stop all running containers
echo "Step 1: Stopping all running containers..."
docker ps -q | xargs -r docker stop 2>/dev/null || true
echo "✅ Containers stopped"
echo ""

# 2. Remove all stopped containers
echo "Step 2: Removing stopped containers..."
docker container prune -f
echo "✅ Stopped containers removed"
echo ""

# 3. Remove all unused images (not just dangling)
echo "Step 3: Removing unused images..."
docker image prune -a -f
echo "✅ Unused images removed"
echo ""

# 4. Remove all unused volumes
echo "Step 4: Removing unused volumes..."
docker volume prune -f
echo "✅ Unused volumes removed"
echo ""

# 5. Remove build cache
echo "Step 5: Removing build cache..."
docker builder prune -a -f
echo "✅ Build cache removed"
echo ""

# 6. Remove all networks (except default)
echo "Step 6: Removing unused networks..."
docker network prune -f
echo "✅ Unused networks removed"
echo ""

# 7. System prune (everything)
echo "Step 7: Full system cleanup..."
docker system prune -a -f --volumes
echo "✅ Full system cleanup done"
echo ""

# Check disk space after cleanup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Disk Usage After Cleanup:"
df -h / | tail -1
echo ""

echo "🐳 Docker Disk Usage After Cleanup:"
docker system df 2>/dev/null || echo "Docker not running"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 If still low on space, check:"
echo "   - Log files: journalctl --vacuum-time=3d"
echo "   - Old backups: find . -name '*.backup.*' -mtime +7"
echo "   - Large files: du -sh /* | sort -h | tail -10"


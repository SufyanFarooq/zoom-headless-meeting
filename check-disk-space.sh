#!/bin/bash

# Quick script to check disk space and Docker usage

echo "📊 Server Disk Space Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "💾 Disk Usage:"
df -h
echo ""

echo "🐳 Docker Disk Usage:"
if command -v docker > /dev/null 2>&1; then
    docker system df
else
    echo "Docker not installed or not accessible"
fi
echo ""

echo "📁 Largest Directories (top 10):"
du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10 || echo "Cannot access root directory"
echo ""

echo "📦 Docker Images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null | head -20 || echo "Docker not accessible"
echo ""

echo "🔍 Docker Containers:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" 2>/dev/null | head -20 || echo "Docker not accessible"
echo ""

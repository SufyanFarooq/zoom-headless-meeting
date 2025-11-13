#!/bin/bash

# Resource Optimization Script for Docker Compose
# Optimizes memory and CPU limits for better efficiency

set -e

COMPOSE_FILE="compose-50-bots.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found"
    echo "   Please run this script in the project directory"
    exit 1
fi

echo "⚙️  Optimizing resource limits in $COMPOSE_FILE..."
echo ""

# Backup original file
if [ ! -f "${COMPOSE_FILE}.backup" ]; then
    cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup"
    echo "✅ Backup created: ${COMPOSE_FILE}.backup"
fi

# Optimize memory limits
echo "📝 Optimizing memory limits..."
sed -i 's/memory: 2G/memory: 200M/g' "$COMPOSE_FILE"
sed -i 's/memory: 512M/memory: 100M/g' "$COMPOSE_FILE"
echo "   ✅ Memory: 2GB → 200MB, 512MB → 100MB"

# Optimize CPU limits
echo "📝 Optimizing CPU limits..."
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" "$COMPOSE_FILE"
sed -i "s/cpus: '0.2'/cpus: '0.1'/g" "$COMPOSE_FILE"
echo "   ✅ CPU: 1.0 → 0.3 cores, 0.2 → 0.1 cores"

# Enable auto-restart
echo "📝 Enabling auto-restart..."
sed -i 's/restart: no/restart: unless-stopped/g' "$COMPOSE_FILE"
echo "   ✅ Restart: no → unless-stopped"

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📊 New resource limits per bot:"
echo "   - Memory Limit: 200MB (was 2GB)"
echo "   - Memory Reservation: 100MB (was 512MB)"
echo "   - CPU Limit: 0.3 cores (was 1.0)"
echo "   - CPU Reservation: 0.1 cores (was 0.2)"
echo "   - Restart Policy: unless-stopped (was no)"
echo ""
echo "📈 Expected improvements:"
echo "   - Can run 60-80 bots (instead of 50)"
echo "   - Better resource efficiency"
echo "   - Auto-restart on failure"
echo ""
echo "🚀 Next steps:"
echo "   1. Review changes: diff $COMPOSE_FILE ${COMPOSE_FILE}.backup"
echo "   2. Restart bots: docker compose -f $COMPOSE_FILE down && docker compose -f $COMPOSE_FILE up -d"
echo "   3. Monitor: watch -n 2 'docker ps | grep zoom-bot | wc -l && docker stats --no-stream | head -10'"
echo ""





#!/bin/bash

# Server Optimization Script
# Optimizes Docker Compose for 60-80 bots

set -e

COMPOSE_FILE="compose-50-bots.yaml"

echo "⚡ Docker Compose Optimization Script"
echo "======================================"
echo ""

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found"
    echo "   Please run this script from the project directory"
    exit 1
fi

# Backup original
echo "📦 Creating backup..."
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created: ${COMPOSE_FILE}.backup.*"

# Optimize resource limits
echo ""
echo "⚙️  Optimizing resource limits..."

# Memory limits: 2G → 512M
sed -i 's/memory: 2G/memory: 512M/g' "$COMPOSE_FILE"
echo "   ✅ Memory limit: 2G → 512M"

# Memory reservations: Replace only in reservations section
# Use context-aware replacement (reservations come after limits)
sed -i '/reservations:/,/memory:/ s/memory: 512M/memory: 100M/g' "$COMPOSE_FILE"
echo "   ✅ Memory reservation: 512M → 100M"

# CPU limits: 1.0 → 0.3
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" "$COMPOSE_FILE"
echo "   ✅ CPU limit: 1.0 → 0.3"

# CPU reservations: 0.2 → 0.1
sed -i "s/cpus: '0.2'/cpus: '0.1'/g" "$COMPOSE_FILE"
echo "   ✅ CPU reservation: 0.2 → 0.1"

# Restart policy: no → unless-stopped
sed -i 's/restart: no/restart: unless-stopped/g' "$COMPOSE_FILE"
echo "   ✅ Restart policy: no → unless-stopped"

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📊 New resource limits per bot:"
echo "   - CPU limit: 0.3 cores (was 1.0)"
echo "   - Memory limit: 512MB (was 2GB)"
echo "   - CPU reservation: 0.1 cores (was 0.2)"
echo "   - Memory reservation: 100MB (was 512MB)"
echo "   - Restart: unless-stopped (was no)"
echo ""
echo "💡 Expected capacity: 60-80 bots (from 50)"
echo ""
echo "📋 Next steps:"
echo "   1. Review changes: diff $COMPOSE_FILE ${COMPOSE_FILE}.backup.*"
echo "   2. Restart bots: docker compose -f $COMPOSE_FILE down && docker compose -f $COMPOSE_FILE up -d"
echo "   3. Monitor: watch -n 2 'docker ps | grep zoom-bot | wc -l'"
echo ""


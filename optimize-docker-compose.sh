#!/bin/bash
# Quick Optimization Script for Docker Compose
# Improves capacity from 50 to 60-80 bots

set -e

echo "🚀 Docker Compose Optimization"
echo "=============================="
echo ""

cd ~/zoom-headless-meeting

COMPOSE_FILE="compose-50-bots.yaml"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    echo "   Please generate it first: ./generate-bots.sh 50"
    exit 1
fi

# Backup original
echo "📦 Creating backup..."
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup"
echo "✅ Backup created: ${COMPOSE_FILE}.backup"

# Optimize resource limits based on actual usage
echo ""
echo "⚙️  Optimizing resource limits..."
echo "   Current: CPU 1.0, Memory 2G (too high!)"
echo "   Optimized: CPU 0.3, Memory 150M (based on actual usage)"

# Update CPU limits
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" "$COMPOSE_FILE"
sed -i "s/cpus: '0.2'/cpus: '0.05'/g" "$COMPOSE_FILE"

# Update memory limits
sed -i 's/memory: 2G/memory: 150M/g' "$COMPOSE_FILE"
sed -i 's/memory: 512M/memory: 50M/g' "$COMPOSE_FILE"

echo "✅ Resource limits optimized!"
echo "   CPU: 0.3 cores (was 1.0) - 70% reduction"
echo "   Memory: 150M (was 2G) - 92% reduction"
echo ""

# Ask for new bot count
read -p "Enter new bot count (60-80 recommended): " NEW_COUNT
NEW_COUNT=${NEW_COUNT:-60}

if [ "$NEW_COUNT" -lt 50 ] || [ "$NEW_COUNT" -gt 100 ]; then
    echo "⚠️  Warning: $NEW_COUNT bots may not be optimal"
    read -p "Continue anyway? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Generate new compose file
echo ""
echo "📝 Generating compose file for $NEW_COUNT bots..."
./generate-bots.sh "$NEW_COUNT"

# Apply optimizations to new file
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" "$COMPOSE_FILE"
sed -i "s/cpus: '0.2'/cpus: '0.05'/g" "$COMPOSE_FILE"
sed -i 's/memory: 2G/memory: 150M/g' "$COMPOSE_FILE"
sed -i 's/memory: 512M/memory: 50M/g' "$COMPOSE_FILE"

echo "✅ Compose file generated and optimized!"
echo ""

# Calculate expected resource usage
EXPECTED_CPU=$((NEW_COUNT * 2))  # 2% per bot
EXPECTED_MEM=$((NEW_COUNT * 100))  # 100MB per bot

echo "📊 Expected Resource Usage:"
echo "   Bots: $NEW_COUNT"
echo "   CPU: ~${EXPECTED_CPU}% (${NEW_COUNT} × 2%)"
echo "   Memory: ~${EXPECTED_MEM}MB (~$((EXPECTED_MEM / 1024))GB)"
echo ""

# Check current resources
CURRENT_CPU=$(nproc)
CURRENT_MEM=$(free -g | awk '/^Mem:/{print $2}')

echo "💻 Server Resources:"
echo "   CPU Cores: $CURRENT_CPU"
echo "   Memory: ${CURRENT_MEM}GB"
echo ""

# Check if resources are sufficient
if [ "$EXPECTED_CPU" -gt $((CURRENT_CPU * 100)) ]; then
    echo "⚠️  Warning: CPU usage may exceed 100%"
fi

if [ "$EXPECTED_MEM" -gt $((CURRENT_MEM * 1024)) ]; then
    echo "⚠️  Warning: Memory usage may exceed available"
fi

echo ""
read -p "Continue with build? (y/n): " BUILD_CONFIRM

if [ "$BUILD_CONFIRM" != "y" ]; then
    echo "✅ Optimization complete! Run build manually:"
    echo "   docker compose -f $COMPOSE_FILE build"
    echo "   docker compose -f $COMPOSE_FILE up -d"
    exit 0
fi

# Build
echo ""
echo "🔨 Building Docker images..."
echo "   This will take 15-20 minutes..."
docker compose -f "$COMPOSE_FILE" build

# Start
echo ""
echo "🚀 Starting $NEW_COUNT bots..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait
sleep 10

# Status
echo ""
echo "✅ Optimization Complete!"
echo ""
echo "📊 Current Status:"
RUNNING=$(docker ps | grep zoom-bot | wc -l)
echo "   Running bots: $RUNNING/$NEW_COUNT"

echo ""
echo "📈 Monitor with:"
echo "   watch -n 2 'docker ps | grep zoom-bot | wc -l && docker stats --no-stream | head -10'"


#!/bin/bash
# Testing script optimized for t3.small instance

set -e

NUM_BOTS=${1:-5}
COMPOSE_FILE="compose-50-bots.yaml"

echo "🧪 Testing on t3.small with $NUM_BOTS bots"
echo "=========================================="
echo ""

# Check if we're on t3.small (optional check)
echo "📊 System Resources:"
free -h
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Generate compose file
echo "📝 Generating compose file for $NUM_BOTS bots..."
./generate-bots.sh $NUM_BOTS

# Optimize resource limits for t3.small
echo "⚙️  Optimizing resource limits for t3.small..."
sed -i 's/memory: 2G/memory: 512M/g' $COMPOSE_FILE
sed -i 's/memory: 512M/memory: 256M/g' $COMPOSE_FILE
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" $COMPOSE_FILE
sed -i "s/cpus: '0.2'/cpus: '0.1'/g" $COMPOSE_FILE

echo "✅ Resource limits optimized:"
echo "   - Memory: 256M per bot (was 2G)"
echo "   - CPU: 0.3 cores per bot (was 1.0)"
echo ""

# Stop existing bots
echo "🛑 Stopping existing bots (if any)..."
docker compose -f $COMPOSE_FILE down 2>/dev/null || true

# Build images (one at a time to avoid memory issues)
echo "🔨 Building Docker images (this may take time)..."
echo "   Building in batches to avoid memory issues..."

# Build first bot to test
docker compose -f $COMPOSE_FILE build bot-1

# If successful, build rest in smaller batches
if [ $NUM_BOTS -gt 1 ]; then
    for i in $(seq 2 $NUM_BOTS); do
        echo "   Building bot-$i..."
        docker compose -f $COMPOSE_FILE build bot-$i || {
            echo "⚠️  Build failed for bot-$i. Stopping at $((i-1)) bots."
            NUM_BOTS=$((i-1))
            break
        }
        
        # Check memory every 5 bots
        if [ $((i % 5)) -eq 0 ]; then
            echo "   Memory check:"
            free -h | grep Mem
        fi
    done
fi

# Start bots
echo ""
echo "🚀 Starting $NUM_BOTS bots..."
docker compose -f $COMPOSE_FILE up -d

# Wait a moment
sleep 5

# Check status
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Current Status:"
docker compose -f $COMPOSE_FILE ps

echo ""
echo "📊 Resource Usage:"
free -h
echo ""
docker stats --no-stream | head -$((NUM_BOTS + 1))

echo ""
echo "📝 Useful Commands:"
echo "   View logs:        docker compose -f $COMPOSE_FILE logs -f"
echo "   Check resources:  docker stats"
echo "   Check memory:     free -h"
echo "   Stop bots:        docker compose -f $COMPOSE_FILE down"
echo "   Count running:    docker ps | grep zoom-bot | wc -l"
echo ""
echo "⚠️  Monitor resources closely on t3.small!"
echo "   If memory > 85%, stop some bots."


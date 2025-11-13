#!/bin/bash
# Staggered Startup Script - Prevents Rate Limiting
# Usage: ./start-optimized.sh [NUM_BOTS]

set -e

NUM_BOTS=${1:-50}
BATCH_SIZE=10
DELAY_BETWEEN_BATCHES=5
DELAY_BETWEEN_BOTS=1

cd ~/zoom-headless-meeting

echo "🚀 Starting $NUM_BOTS Bots (Optimized - Staggered)"
echo "=================================================="
echo ""
echo "📊 Configuration:"
echo "   Total Bots: $NUM_BOTS"
echo "   Batch Size: $BATCH_SIZE"
echo "   Delay Between Batches: ${DELAY_BETWEEN_BATCHES}s"
echo "   Delay Between Bots: ${DELAY_BETWEEN_BOTS}s"
echo ""

# Check if compose file exists
if [ ! -f "compose-50-bots.yaml" ]; then
    echo "❌ Error: compose-50-bots.yaml not found"
    exit 1
fi

# Stop existing bots
echo "🛑 Stopping existing bots..."
docker compose -f compose-50-bots.yaml down 2>/dev/null || true
sleep 2

# Start bots in batches
echo ""
echo "🚀 Starting bots in batches..."
echo ""

BATCH_NUM=1
for i in $(seq 1 $NUM_BOTS); do
    # Check if new batch
    if [ $((i % BATCH_SIZE)) -eq 1 ] && [ $i -gt 1 ]; then
        echo ""
        echo "⏳ Batch $BATCH_NUM complete. Waiting ${DELAY_BETWEEN_BATCHES}s before next batch..."
        sleep $DELAY_BETWEEN_BATCHES
        BATCH_NUM=$((BATCH_NUM + 1))
        echo ""
    fi
    
    # Start bot
    echo -n "   Starting bot-$i... "
    docker compose -f compose-50-bots.yaml up -d bot-$i >/dev/null 2>&1 && echo "✅" || echo "❌"
    
    # Small delay between bots
    sleep $DELAY_BETWEEN_BOTS
done

echo ""
echo "✅ All bots started!"
echo ""

# Wait for authentication
echo "⏳ Waiting 15 seconds for authentication..."
sleep 15

# Check status
RUNNING=$(docker ps | grep zoom-bot | wc -l)
echo ""
echo "📊 Status:"
echo "   Running: $RUNNING/$NUM_BOTS"
echo ""

if [ "$RUNNING" -lt $NUM_BOTS ]; then
    echo "⚠️  Some bots may still be starting. Check again in 30 seconds:"
    echo "   docker ps | grep zoom-bot | wc -l"
    echo ""
    echo "📋 Check logs for errors:"
    echo "   docker compose -f compose-50-bots.yaml logs | grep -i error | tail -20"
else
    echo "✅ All bots running successfully!"
fi

echo ""
echo "📈 Monitor resources:"
echo "   watch -n 2 'docker ps | grep zoom-bot | wc -l && docker stats --no-stream | head -15'"


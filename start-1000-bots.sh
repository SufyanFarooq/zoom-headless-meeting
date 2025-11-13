#!/bin/bash

# Staggered Startup Script for 1000 Bots
# Prevents rate limiting by starting bots in batches

set -e

BATCH_SIZE=50
DELAY=10
TOTAL=1000
COMPOSE_FILE="compose-50-bots.yaml"

echo "🚀 Starting $TOTAL bots in batches of $BATCH_SIZE..."
echo "   Delay between batches: $DELAY seconds"
echo ""

cd ~/zoom-headless-meeting

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found"
    echo "   Please generate it first: ./generate-bots.sh $TOTAL"
    exit 1
fi

# Count existing bots
EXISTING=$(docker ps | grep zoom-bot | wc -l)
if [ "$EXISTING" -gt 0 ]; then
    echo "⚠️  Warning: $EXISTING bots already running"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📊 Starting bots..."
echo ""

START_TIME=$(date +%s)
BATCH_NUM=1

for i in $(seq 1 $TOTAL); do
    # Check if batch boundary
    if [ $((i % BATCH_SIZE)) -eq 1 ] && [ $i -gt 1 ]; then
        BATCH_NUM=$((BATCH_NUM + 1))
        RUNNING=$(docker ps | grep zoom-bot | wc -l)
        ELAPSED=$(( $(date +%s) - START_TIME ))
        echo ""
        echo "⏳ Batch $((BATCH_NUM - 1)) complete. Running: $RUNNING/$TOTAL"
        echo "   Elapsed: ${ELAPSED}s | Waiting $DELAY seconds before next batch..."
        sleep $DELAY
    fi
    
    # Start bot
    echo -n "."
    docker compose -f "$COMPOSE_FILE" up -d bot-$i 2>/dev/null || true
    
    # Small delay between individual bots
    sleep 0.3
    
    # Progress update every 100 bots
    if [ $((i % 100)) -eq 0 ]; then
        RUNNING=$(docker ps | grep zoom-bot | wc -l)
        echo ""
        echo "   Progress: $i/$TOTAL started, $RUNNING running"
    fi
done

echo ""
echo ""
echo "✅ All $TOTAL bots started!"
echo ""

# Final count
sleep 5
RUNNING=$(docker ps | grep zoom-bot | wc -l)
ELAPSED=$(( $(date +%s) - START_TIME ))

echo "📊 Final Status:"
echo "   Running: $RUNNING/$TOTAL"
echo "   Time taken: ${ELAPSED}s"
echo ""
echo "📈 Monitor with:"
echo "   watch -n 2 'docker ps | grep zoom-bot | wc -l && docker stats --no-stream | head -15'"
echo ""


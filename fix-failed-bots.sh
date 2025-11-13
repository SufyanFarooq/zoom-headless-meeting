#!/bin/bash

# Quick Fix Script: Restart Failed Bots
# Usage: ./fix-failed-bots.sh

set -e

echo "🔍 Finding failed bots..."

cd ~/zoom-headless-meeting

# Find stopped bots
STOPPED_BOTS=$(docker ps -a | grep zoom-bot | grep -v "Up" | awk '{print $NF}' | sed 's/zoom-bot-//' || true)

if [ -z "$STOPPED_BOTS" ]; then
    echo "✅ No failed bots found!"
    echo "📊 Running bots: $(docker ps | grep zoom-bot | wc -l)/50"
    exit 0
fi

echo "❌ Found failed bots: $STOPPED_BOTS"
echo ""
echo "🔄 Restarting failed bots (with 3 second delay to prevent rate limiting)..."
echo ""

# Restart each bot with delay
for bot in $STOPPED_BOTS; do
    echo "   Restarting bot-$bot..."
    docker compose -f compose-50-bots.yaml restart bot-$bot || true
    sleep 3
done

echo ""
echo "⏳ Waiting 10 seconds for bots to authenticate..."
sleep 10

# Final count
RUNNING=$(docker ps | grep zoom-bot | wc -l)
echo ""
echo "✅ Restart complete!"
echo "📊 Running bots: $RUNNING/50"

if [ "$RUNNING" -lt 50 ]; then
    echo ""
    echo "⚠️  Some bots may still be starting. Check again in 30 seconds:"
    echo "   docker ps | grep zoom-bot | wc -l"
    echo ""
    echo "📋 Check logs for errors:"
    echo "   docker compose -f compose-50-bots.yaml logs | grep 'error: 5'"
fi





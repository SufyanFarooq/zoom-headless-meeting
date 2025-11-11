#!/bin/bash

# Stop all running bots
# Usage: ./stop-bots.sh [number-of-bots]

NUM_BOTS=${1:-50}

echo "🛑 Stopping all bots..."

for i in $(seq 1 $NUM_BOTS); do
    docker stop "zoom-bot-${i}" > /dev/null 2>&1
done

# Also stop any remaining
docker ps -a | grep zoom-bot | awk '{print $1}' | xargs -r docker stop > /dev/null 2>&1

echo "✅ All bots stopped!"


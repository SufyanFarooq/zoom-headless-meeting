#!/bin/bash

# Script to run multiple Zoom bots simultaneously with different names
# Usage: ./run-multiple-bots.sh

# Number of bots to run
NUM_BOTS=10

# Base configuration
CLIENT_ID="vdPX1q2bSQKip0X17LqXAw"
CLIENT_SECRET="Te1YdXaBL6IScwdBVlNF0kay75KDMkyz"
JOIN_URL="https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022"

# Bot names
BOT_NAMES=(
    "Bot-1-Alice"
    "Bot-2-Bob"
    "Bot-3-Charlie"
    "Bot-4-Diana"
    "Bot-5-Eve"
    "Bot-6-Frank"
    "Bot-7-Grace"
    "Bot-8-Henry"
    "Bot-9-Iris"
    "Bot-10-Jack"
)

echo "🚀 Starting $NUM_BOTS bots..."

# Create output directories for each bot
for i in $(seq 1 $NUM_BOTS); do
    mkdir -p "out/bot-$i"
done

# Function to run a single bot
run_bot() {
    local bot_num=$1
    local bot_name=$2
    local output_dir="out/bot-$bot_num"
    
    echo "🤖 Starting $bot_name (Bot $bot_num)..."
    
    docker run -d \
        --name "zoom-bot-$bot_num" \
        --rm \
        -v "$(pwd):/tmp/meeting-sdk-linux-sample" \
        -e DISPLAY_NAME="$bot_name" \
        -e JOIN_URL="$JOIN_URL" \
        -e CLIENT_ID="$CLIENT_ID" \
        -e CLIENT_SECRET="$CLIENT_SECRET" \
        -e OUTPUT_DIR="$output_dir" \
        meetingsdk-headless-linux-sample-zoomsdk \
        /bin/bash -c "
            cd /tmp/meeting-sdk-linux-sample && \
            ./build/zoomsdk \
                --client-id '$CLIENT_ID' \
                --client-secret '$CLIENT_SECRET' \
                --join-url '$JOIN_URL' \
                --display-name '$bot_name' \
                RawAudio --file 'bot-$bot_num-audio.pcm' --dir '$output_dir' \
                RawVideo --file 'bot-$bot_num-video.mp4' --dir '$output_dir'
        "
}

# Start all bots
for i in $(seq 1 $NUM_BOTS); do
    bot_name="${BOT_NAMES[$((i-1))]}"
    run_bot $i "$bot_name" &
    sleep 2  # Stagger the starts slightly
done

echo "✅ All $NUM_BOTS bots started!"
echo "📊 Check status with: docker ps | grep zoom-bot"
echo "📝 View logs with: docker logs zoom-bot-<number>"
echo "🛑 Stop all bots with: ./stop-all-bots.sh"


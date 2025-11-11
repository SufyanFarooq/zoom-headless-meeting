#!/bin/bash

# Smart script to run multiple bots using Docker directly (no compose file needed)
# Usage: ./run-bots.sh [number-of-bots] [meeting-url]

NUM_BOTS=${1:-50}
JOIN_URL=${2:-"https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022"}
CLIENT_ID="vdPX1q2bSQKip0X17LqXAw"
CLIENT_SECRET="Te1YdXaBL6IScwdBVlNF0kay75KDMkyz"

# Generate bot names array
BOT_NAMES=(
    "Alice" "Bob" "Charlie" "Diana" "Eve" "Frank" "Grace" "Henry" "Iris" "Jack"
    "Kevin" "Laura" "Mike" "Nancy" "Oscar" "Patricia" "Quinn" "Rachel" "Steve" "Tina"
    "Uma" "Victor" "Wendy" "Xavier" "Yara" "Zack" "Anna" "Ben" "Cara" "David"
    "Emma" "Felix" "Gina" "Hugo" "Ivy" "Jake" "Kate" "Leo" "Maya" "Noah"
    "Olivia" "Paul" "Quinn" "Rose" "Sam" "Tara" "Uma" "Vince" "Will" "Xara"
)

echo "🚀 Starting $NUM_BOTS bots..."

# Build image first (if not already built)
if ! docker images | grep -q "meetingsdk-headless-linux-sample-zoomsdk"; then
    echo "📦 Building Docker image..."
    docker compose build
fi

# Start bots
for i in $(seq 1 $NUM_BOTS); do
    BOT_NUM=$i
    NAME_INDEX=$(( (i - 1) % ${#BOT_NAMES[@]} ))
    BOT_NAME="${BOT_NAMES[$NAME_INDEX]}"
    FULL_NAME="Bot-${BOT_NUM}-${BOT_NAME}"
    
    echo "🤖 Starting $FULL_NAME (Bot $BOT_NUM/$NUM_BOTS)..."
    
    docker run -d \
        --name "zoom-bot-${BOT_NUM}" \
        --rm \
        -v "$(pwd):/tmp/meeting-sdk-linux-sample" \
        -v "build-cache:/tmp/meeting-sdk-linux-sample/build" \
        -e DISPLAY_NAME="${FULL_NAME}" \
        -e JOIN_URL="${JOIN_URL}" \
        -e CLIENT_ID="${CLIENT_ID}" \
        -e CLIENT_SECRET="${CLIENT_SECRET}" \
        -e QT_LOGGING_RULES="*.debug=false;*.warning=false;*.info=false;*.critical=false" \
        -e QT_QPA_PLATFORM="offscreen" \
        -e G_MESSAGES_DEBUG="" \
        --cpus="0.5" \
        --memory="150m" \
        --restart unless-stopped \
        meetingsdk-headless-linux-sample-zoomsdk \
        /bin/bash -c "
            cd /tmp/meeting-sdk-linux-sample && \
            ./bin/entry-bot-optimized.sh \
                --client-id '${CLIENT_ID}' \
                --client-secret '${CLIENT_SECRET}' \
                --join-url '${JOIN_URL}' \
                --display-name '${FULL_NAME}'
        " > /dev/null 2>&1
    
    # Small delay to avoid overwhelming system
    sleep 0.5
done

echo ""
echo "✅ All $NUM_BOTS bots started!"
echo ""
echo "📊 Check status:"
echo "   docker ps | grep zoom-bot | wc -l"
echo ""
echo "📝 View logs:"
echo "   docker logs zoom-bot-1"
echo ""
echo "🛑 Stop all bots:"
echo "   ./stop-bots.sh $NUM_BOTS"


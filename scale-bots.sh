#!/bin/bash

# Script to scale up the number of bots in compose-50-bots.yaml

set -e

COMPOSE_FILE="compose-50-bots.yaml"
CURRENT_BOTS=50
TARGET_BOTS=${1:-100}

if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_bots>"
    echo "Example: $0 100  # Scale to 100 bots"
    echo ""
    echo "Current bots: $CURRENT_BOTS"
    exit 1
fi

if [ "$TARGET_BOTS" -le "$CURRENT_BOTS" ]; then
    echo "❌ Target bots ($TARGET_BOTS) must be greater than current ($CURRENT_BOTS)"
    exit 1
fi

echo "🔄 Scaling bots from $CURRENT_BOTS to $TARGET_BOTS..."
echo ""

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    exit 1
fi

# Create backup
BACKUP_FILE="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"
echo ""

# Read bot-1 configuration as template
BOT_TEMPLATE=$(awk '/^  bot-1:/,/^  bot-2:/ {if (!/^  bot-2:/) print}' "$COMPOSE_FILE")

# Extract bot-1 configuration
BOT_NUM=$((CURRENT_BOTS + 1))
ADDED=0

echo "Adding bots $((CURRENT_BOTS + 1)) to $TARGET_BOTS..."
echo ""

# Find the last bot entry
LAST_BOT_LINE=$(grep -n "^  bot-" "$COMPOSE_FILE" | tail -1 | cut -d: -f1)

# Insert new bots before the volumes section (if exists) or at the end
while [ $BOT_NUM -le $TARGET_BOTS ]; do
    # Generate bot name
    BOT_NAME="bot-${BOT_NUM}"
    
    # Generate display name (cycle through names if needed)
    NAMES=("Alice" "Bob" "Charlie" "Diana" "Eve" "Frank" "Grace" "Henry" "Iris" "Jack")
    NAME_INDEX=$(((BOT_NUM - 1) % 10))
    DISPLAY_NAME="Bot-${BOT_NUM}-${NAMES[$NAME_INDEX]}"
    
    # Generate video file number (cycle through 1-10)
    VIDEO_NUM=$(((BOT_NUM - 1) % 10) + 1)
    
    # Create bot configuration
    BOT_CONFIG="  ${BOT_NAME}:
    build: ./
    platform: linux/amd64
    container_name: zoom-${BOT_NAME}
    volumes:
     - .:/tmp/meeting-sdk-linux-sample
     - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
     - DISPLAY_NAME=${DISPLAY_NAME}
     - JOIN_URL=https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022
     - CLIENT_ID=vdPX1q2bSQKip0X17LqXAw
     - CLIENT_SECRET=Te1YdXaBL6IScwdBVlNF0kay75KDMkyz
     - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
     - QT_QPA_PLATFORM=offscreen
     - G_MESSAGES_DEBUG=
    entrypoint: [\"/tini\", \"--\", \"./bin/entry-bot-optimized.sh\"]
    command:
      - \"--client-id\"
      - \"vdPX1q2bSQKip0X17LqXAw\"
      - \"--client-secret\"
      - \"Te1YdXaBL6IScwdBVlNF0kay75KDMkyz\"
      - \"--join-url\"
      - \"https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022\"
      - \"--display-name\"
      - \"${DISPLAY_NAME}\"
      - \"--config\"
      - \"config.toml\"
      - \"RawVideo\"
      - \"--input\"
      - \"videos/video-${VIDEO_NUM}.mp4\"
      - \"RawAudio\"
      - \"--file\"
      - \"dev-null.pcm\"
      - \"--dir\"
      - \"/dev\"
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 256M
        reservations:
          cpus: '0.05'
          memory: 128M
    stop_grace_period: 2s
    restart: no
"

    # Append bot configuration to a temporary file
    echo "$BOT_CONFIG" >> /tmp/new_bots_$$.yaml
    
    ADDED=$((ADDED + 1))
    BOT_NUM=$((BOT_NUM + 1))
    
    if [ $((ADDED % 10)) -eq 0 ]; then
        echo "  ✅ Added $ADDED bots so far..."
    fi
done

# Insert all new bots before volumes section
if [ -f /tmp/new_bots_$$.yaml ] && [ -s /tmp/new_bots_$$.yaml ]; then
    echo "Inserting $ADDED bots into compose file..."
    if grep -q "^volumes:" "$COMPOSE_FILE"; then
        # Insert before volumes section using sed
        sed -i.bak "/^volumes:/r /tmp/new_bots_$$.yaml" "$COMPOSE_FILE"
    else
        # Append at end of file
        cat /tmp/new_bots_$$.yaml >> "$COMPOSE_FILE"
    fi
    rm -f /tmp/new_bots_$$.yaml
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Successfully added $ADDED bots!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "  Previous bots: $CURRENT_BOTS"
echo "  New bots: $ADDED"
echo "  Total bots: $TARGET_BOTS"
echo ""
echo "💡 Next steps:"
echo "  1. Check resources: ./check-server-resources.sh"
echo "  2. Test with a few bots: docker compose -f $COMPOSE_FILE up bot-51 bot-52"
echo "  3. Run all bots: docker compose -f $COMPOSE_FILE up -d"
echo "  4. Monitor: docker stats"
echo ""


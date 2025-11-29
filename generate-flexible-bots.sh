#!/bin/bash

# Generate flexible bots compose file
# Usage: ./generate-flexible-bots.sh <video_count> <audio_count> <join_url> <display_name_prefix> [users_file] [name_type] [meeting_id] [request_id]
# name_type: "Indian" (default) or "International" - determines which names file to use
# meeting_id: Meeting ID for unique container names (optional, defaults to timestamp)
# request_id: Unique request ID for this bot creation (optional, defaults to timestamp)

set -e

VIDEO_ONLY_COUNT=${1:-0}
AUDIO_ONLY_COUNT=${2:-0}
JOIN_URL=${3:-""}
DISPLAY_NAME_PREFIX=${4:-"Bot"}

USERS_FILE="${5:-profile-pics/users.txt}"
NAME_TYPE="${6:-Indian}"
MEETING_ID="${7:-}"
REQUEST_ID="${8:-}"

# If meeting ID not provided, use timestamp for uniqueness
if [ -z "$MEETING_ID" ]; then
    MEETING_ID="$(date +%s)"
    echo "⚠️  No Meeting ID provided, using timestamp: $MEETING_ID"
else
    echo "✅ Using Meeting ID: $MEETING_ID"
fi

# If request ID not provided, use timestamp for uniqueness
if [ -z "$REQUEST_ID" ]; then
    REQUEST_ID="$(date +%s)"
    echo "⚠️  No Request ID provided, using timestamp: $REQUEST_ID"
else
    echo "✅ Using Request ID: $REQUEST_ID"
fi

# Select names file based on name type
if [ "$NAME_TYPE" = "International" ]; then
    NAMES_FILE="profile-pics/names-international.txt"
else
    NAMES_FILE="profile-pics/names.txt"
fi

# Function to get display name from names.txt
get_display_name() {
    local bot_num=$1
    local name=""
    
    # Read name from names.txt (line number = bot number)
    if [ -f "$NAMES_FILE" ]; then
        name=$(sed -n "${bot_num}p" "$NAMES_FILE" 2>/dev/null | xargs)
        
        # Skip empty lines and comments
        if [ -z "$name" ] || [[ "$name" =~ ^# ]]; then
            name=""
        fi
    fi
    
    # Fallback: If no name found, try to extract from users.txt email
    if [ -z "$name" ] && [ -f "$USERS_FILE" ]; then
        local line=$(sed -n "${bot_num}p" "$USERS_FILE" 2>/dev/null)
        if [ -n "$line" ] && [[ "$line" =~ @ ]]; then
            local email=$(echo "$line" | awk '{print $1}')
            name=$(echo "$email" | cut -d'@' -f1)
            # Capitalize first letter
            name=$(echo "$name" | sed 's/^./\U&/')
        fi
    fi
    
    # Final fallback to prefix-number
    if [ -z "$name" ]; then
        name="${DISPLAY_NAME_PREFIX}-${bot_num}"
    fi
    
    echo "$name"
}

# Use meeting ID + request ID for unique compose file name
# This ensures each bot creation request gets its own compose file
COMPOSE_FILE="compose-${MEETING_ID}-${REQUEST_ID}-bots.yaml"
TEMP_FILE="${COMPOSE_FILE}.tmp"

if [ -z "$JOIN_URL" ]; then
    echo "❌ Error: Join URL is required"
    exit 1
fi

# Calculate total bots
TOTAL_BOTS=$((VIDEO_ONLY_COUNT + AUDIO_ONLY_COUNT))

if [ $TOTAL_BOTS -eq 0 ]; then
    echo "❌ Error: At least one bot type must be specified"
    exit 1
fi

echo "📝 Generating compose file with:"
echo "   - Video-only bots: $VIDEO_ONLY_COUNT"
echo "   - Audio-only bots: $AUDIO_ONLY_COUNT"
echo "   - Total bots: $TOTAL_BOTS"

# Start compose file
cat > "$TEMP_FILE" << 'EOF'
services:
EOF

BOT_NUMBER=1

# Generate Video-only bots
if [ $VIDEO_ONLY_COUNT -gt 0 ]; then
    echo "📹 Generating $VIDEO_ONLY_COUNT video-only bots..."
    for i in $(seq 1 $VIDEO_ONLY_COUNT); do
        VIDEO_NUM=$(( (BOT_NUMBER - 1) % 100 + 1 ))
        DISPLAY_NAME=$(get_display_name $BOT_NUMBER)
        cat >> "$TEMP_FILE" << EOF
  bot-${MEETING_ID}-${REQUEST_ID}-${BOT_NUMBER}:
    image: zoom-bot:latest
    container_name: zoom-bot-${MEETING_ID}-${REQUEST_ID}-${BOT_NUMBER}
    volumes:
    - ${HOST_PROJECT_PATH:-.}:/tmp/meeting-sdk-linux-sample
    - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
    - DISPLAY_NAME=${DISPLAY_NAME}
    - JOIN_URL=${JOIN_URL}
    - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
    - QT_QPA_PLATFORM=offscreen
    - G_MESSAGES_DEBUG=
    working_dir: /tmp/meeting-sdk-linux-sample
    entrypoint:
    - /tini
    - --
    - ./bin/entry-bot-optimized.sh
    command:
    - --join-url
    - ${JOIN_URL}
    - --display-name
    - ${DISPLAY_NAME}
    - --config
    - config.toml
    - RawVideo
    - --input
    - videos/video-${VIDEO_NUM}.mp4
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 256M
        reservations:
          cpus: '0.05'
          memory: 128M
    stop_grace_period: 2s
    restart: 'no'
EOF
        BOT_NUMBER=$((BOT_NUMBER + 1))
    done
fi

# Generate Audio-only bots
if [ $AUDIO_ONLY_COUNT -gt 0 ]; then
    echo "🔊 Generating $AUDIO_ONLY_COUNT audio-only bots..."
    for i in $(seq 1 $AUDIO_ONLY_COUNT); do
        DISPLAY_NAME=$(get_display_name $BOT_NUMBER)
        cat >> "$TEMP_FILE" << EOF
  bot-${MEETING_ID}-${REQUEST_ID}-${BOT_NUMBER}:
    image: zoom-bot:latest
    container_name: zoom-bot-${MEETING_ID}-${REQUEST_ID}-${BOT_NUMBER}
    volumes:
    - ${HOST_PROJECT_PATH:-.}:/tmp/meeting-sdk-linux-sample
    - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
    - DISPLAY_NAME=${DISPLAY_NAME}
    - JOIN_URL=${JOIN_URL}
    - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
    - QT_QPA_PLATFORM=offscreen
    - G_MESSAGES_DEBUG=
    working_dir: /tmp/meeting-sdk-linux-sample
    entrypoint:
    - /tini
    - --
    - ./bin/entry-bot-optimized.sh
    command:
    - --join-url
    - ${JOIN_URL}
    - --display-name
    - ${DISPLAY_NAME}
    - --config
    - config.toml
    - RawAudio
    - --file
    - dev-null.pcm
    - --dir
    - "/dev"
    deploy:
      resources:
        limits:
          cpus: '0.2'
          memory: 192M
        reservations:
          cpus: '0.03'
          memory: 96M
    stop_grace_period: 2s
    restart: 'no'
EOF
        BOT_NUMBER=$((BOT_NUMBER + 1))
    done
fi


# Add volumes section
cat >> "$TEMP_FILE" << 'EOF'

volumes:
  build-cache:
EOF

# Replace original file
rm -f "$COMPOSE_FILE"
mv "$TEMP_FILE" "$COMPOSE_FILE"

echo "✅ Generated $COMPOSE_FILE with $TOTAL_BOTS bots"
echo "   - Video-only: $VIDEO_ONLY_COUNT"
echo "   - Audio-only: $AUDIO_ONLY_COUNT"


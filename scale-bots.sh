#!/bin/bash

# Script to scale up bots in compose-50-bots.yaml with flexible video/audio counts
# Usage: ./scale-bots.sh <total_bots> <video_count> <audio_count> [join_url]

set -e

COMPOSE_FILE="compose-50-bots.yaml"
USERS_FILE="profile-pics/users.txt"
NAMES_FILE="profile-pics/names.txt"

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
    
    # Final fallback to Bot-number
    if [ -z "$name" ]; then
        name="Bot-${bot_num}"
    fi
    
    echo "$name"
}

# Parse arguments
TOTAL_BOTS=${1:-0}
VIDEO_COUNT=${2:-0}
AUDIO_COUNT=${3:-0}
JOIN_URL=${4:-""}

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <total_bots> <video_count> <audio_count> [join_url]"
    echo ""
    echo "Parameters:"
    echo "  total_bots:   Total target bots (must be >= current total)"
    echo "  video_count:  Target video-only bots"
    echo "  audio_count:  Target audio-only bots"
    echo ""
    echo "Validation:"
    echo "  - total_bots >= current total bots"
    echo "  - video_count + audio_count <= total_bots"
    echo ""
    echo "Examples:"
    echo "  $0 20 10 5                    # Scale to 20 total (10 video + 5 audio, 5 unused)"
    echo "  $0 15 15 0 'https://zoom.us/j/xxx'  # Scale to 15 total (15 video, 0 audio)"
    echo ""
    echo "Current bots in compose file:"
    if [ -f "$COMPOSE_FILE" ]; then
        CURRENT_VIDEO=$(grep -c "RawVideo" "$COMPOSE_FILE" 2>/dev/null || echo "0")
        CURRENT_AUDIO=$(grep -c "RawAudio" "$COMPOSE_FILE" 2>/dev/null || echo "0")
        CURRENT_TOTAL=$(grep -c "^  bot-" "$COMPOSE_FILE" 2>/dev/null || echo "0")
        echo "  Video-only: $CURRENT_VIDEO"
        echo "  Audio-only: $CURRENT_AUDIO"
        echo "  Total: $CURRENT_TOTAL"
    else
        echo "  Compose file not found"
    fi
    exit 1
fi

# Validate: video_count + audio_count <= total_bots
SUM_COUNTS=$((VIDEO_COUNT + AUDIO_COUNT))
if [ "$SUM_COUNTS" -gt "$TOTAL_BOTS" ]; then
    echo "❌ Error: video_count ($VIDEO_COUNT) + audio_count ($AUDIO_COUNT) = $SUM_COUNTS"
    echo "   This exceeds total_bots ($TOTAL_BOTS)"
    echo "   💡 video_count + audio_count must be <= total_bots"
    exit 1
fi

# Detect current bot counts
if [ -f "$COMPOSE_FILE" ]; then
    CURRENT_VIDEO=$(grep -c "RawVideo" "$COMPOSE_FILE" 2>/dev/null || echo "0")
    CURRENT_AUDIO=$(grep -c "RawAudio" "$COMPOSE_FILE" 2>/dev/null || echo "0")
    CURRENT_TOTAL=$((CURRENT_VIDEO + CURRENT_AUDIO))
else
    CURRENT_VIDEO=0
    CURRENT_AUDIO=0
    CURRENT_TOTAL=0
fi

# Validate: total_bots >= current total
if [ "$TOTAL_BOTS" -lt "$CURRENT_TOTAL" ]; then
    echo "❌ Error: total_bots ($TOTAL_BOTS) must be >= current total ($CURRENT_TOTAL)"
    echo "   💡 To scale down, use ./setup-flexible-bots.sh to regenerate the file"
    exit 1
fi

# Get join URL from existing compose file if not provided
if [ -z "$JOIN_URL" ]; then
    if [ -f "$COMPOSE_FILE" ]; then
        JOIN_URL=$(grep -A 1 "JOIN_URL=" "$COMPOSE_FILE" | head -1 | sed 's/.*JOIN_URL=//' | tr -d '"' | tr -d "'" || echo "")
        if [ -z "$JOIN_URL" ]; then
            JOIN_URL=$(grep -A 5 "command:" "$COMPOSE_FILE" | grep -A 1 "--join-url" | tail -1 | sed 's/.*--join-url//' | xargs || echo "")
        fi
    fi
    
    if [ -z "$JOIN_URL" ]; then
        echo "❌ Error: Join URL not found in compose file and not provided"
        echo "   Please provide join URL as 4th argument"
        exit 1
    fi
fi

# Check if already at target
if [ "$VIDEO_COUNT" -eq "$CURRENT_VIDEO" ] && [ "$AUDIO_COUNT" -eq "$CURRENT_AUDIO" ] && [ "$TOTAL_BOTS" -eq "$CURRENT_TOTAL" ]; then
    echo "✅ Already at target counts: $VIDEO_COUNT video, $AUDIO_COUNT audio, $TOTAL_BOTS total"
    exit 0
fi

echo "🔄 Scaling bots..."
echo "   Current: $CURRENT_VIDEO video-only, $CURRENT_AUDIO audio-only (Total: $CURRENT_TOTAL)"
echo "   Target:  $VIDEO_COUNT video-only, $AUDIO_COUNT audio-only (Total: $TOTAL_BOTS)"
echo "   Note: video + audio = $SUM_COUNTS, remaining capacity = $((TOTAL_BOTS - SUM_COUNTS))"
echo ""

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    echo "   💡 Run ./setup-flexible-bots.sh first to create the file"
    exit 1
fi

# Calculate how many bots to add
VIDEO_TO_ADD=$((VIDEO_COUNT - CURRENT_VIDEO))
AUDIO_TO_ADD=$((AUDIO_COUNT - CURRENT_AUDIO))
TOTAL_TO_ADD=$((VIDEO_TO_ADD + AUDIO_TO_ADD))

if [ $TOTAL_TO_ADD -le 0 ]; then
    echo "✅ No bots to add"
    exit 0
fi

echo "📝 Adding bots:"
echo "   +$VIDEO_TO_ADD video-only bots"
echo "   +$AUDIO_TO_ADD audio-only bots"
echo "   Total: +$TOTAL_TO_ADD bots"
echo ""

# Start from the next bot number
BOT_NUMBER=$((CURRENT_TOTAL + 1))
ADDED=0

# Generate video-only bots
if [ $VIDEO_TO_ADD -gt 0 ]; then
    echo "📹 Adding $VIDEO_TO_ADD video-only bots (bot-$BOT_NUMBER to bot-$((BOT_NUMBER + VIDEO_TO_ADD - 1)))..."
    
    for i in $(seq 1 $VIDEO_TO_ADD); do
        VIDEO_NUM=$(( (BOT_NUMBER - 1) % 100 + 1 ))
        DISPLAY_NAME=$(get_display_name $BOT_NUMBER)
        
        BOT_CONFIG="  bot-${BOT_NUMBER}:
    build: ./
    platform: linux/amd64
    container_name: zoom-bot-${BOT_NUMBER}
    volumes:
    - .:/tmp/meeting-sdk-linux-sample
    - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
    - DISPLAY_NAME=${DISPLAY_NAME}
    - JOIN_URL=${JOIN_URL}
    - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
    - QT_QPA_PLATFORM=offscreen
    - G_MESSAGES_DEBUG=
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
"
        
        echo "$BOT_CONFIG" >> /tmp/new_bots_$$.yaml
        BOT_NUMBER=$((BOT_NUMBER + 1))
        ADDED=$((ADDED + 1))
    done
fi

# Generate audio-only bots
if [ $AUDIO_TO_ADD -gt 0 ]; then
    echo "🔊 Adding $AUDIO_TO_ADD audio-only bots (bot-$BOT_NUMBER to bot-$((BOT_NUMBER + AUDIO_TO_ADD - 1)))..."
    
    for i in $(seq 1 $AUDIO_TO_ADD); do
        DISPLAY_NAME=$(get_display_name $BOT_NUMBER)
        
        BOT_CONFIG="  bot-${BOT_NUMBER}:
    build: ./
    platform: linux/amd64
    container_name: zoom-bot-${BOT_NUMBER}
    volumes:
    - .:/tmp/meeting-sdk-linux-sample
    - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
    - DISPLAY_NAME=${DISPLAY_NAME}
    - JOIN_URL=${JOIN_URL}
    - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
    - QT_QPA_PLATFORM=offscreen
    - G_MESSAGES_DEBUG=
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
"
        
        echo "$BOT_CONFIG" >> /tmp/new_bots_$$.yaml
        BOT_NUMBER=$((BOT_NUMBER + 1))
        ADDED=$((ADDED + 1))
    done
fi

# Insert new bots into compose file
if [ -f /tmp/new_bots_$$.yaml ] && [ -s /tmp/new_bots_$$.yaml ]; then
    echo ""
    echo "📝 Inserting $ADDED bots into compose file..."
    
    # Use Python for reliable YAML insertion
    python3 << PYTHON_SCRIPT
import re

with open("$COMPOSE_FILE", 'r') as f:
    lines = f.readlines()

# Find the line number where volumes: starts
volumes_line = None
for i, line in enumerate(lines):
    if re.match(r'^volumes:', line):
        volumes_line = i
        break

# Find the last bot entry (before volumes:)
last_bot_line = None
for i in range(len(lines) - 1, -1, -1):
    if re.match(r'^  bot-\d+:', lines[i]):
        # Find the end of this bot (next blank line or start of volumes)
        end_line = i + 1
        while end_line < len(lines):
            # Stop at blank line (end of bot) or volumes: (start of volumes section)
            if not lines[end_line].strip() or re.match(r'^volumes:', lines[end_line]):
                break
            # Stop if we hit another bot
            if re.match(r'^  bot-\d+:', lines[end_line]):
                break
            end_line += 1
        last_bot_line = end_line
        break

# Read new bots
with open("/tmp/new_bots_$$.yaml", 'r') as f:
    new_bots = f.read()

# Insert new bots after last bot, before volumes
if volumes_line is not None and last_bot_line is not None:
    insert_pos = min(last_bot_line, volumes_line)
elif volumes_line is not None:
    insert_pos = volumes_line
elif last_bot_line is not None:
    insert_pos = last_bot_line
else:
    insert_pos = len(lines)

# Ensure we add a newline before inserting if needed
if insert_pos > 0 and lines[insert_pos - 1].strip():
    new_bots = '\n' + new_bots

# Insert new bots
lines.insert(insert_pos, new_bots)

with open("$COMPOSE_FILE", 'w') as f:
    f.writelines(lines)
PYTHON_SCRIPT

    rm -f /tmp/new_bots_$$.yaml
    
    # Verify
    NEW_VIDEO=$(grep -c "RawVideo" "$COMPOSE_FILE" 2>/dev/null || echo "0")
    NEW_AUDIO=$(grep -c "RawAudio" "$COMPOSE_FILE" 2>/dev/null || echo "0")
    NEW_TOTAL=$((NEW_VIDEO + NEW_AUDIO))
    
    if [ "$NEW_VIDEO" -eq "$VIDEO_COUNT" ] && [ "$NEW_AUDIO" -eq "$AUDIO_COUNT" ]; then
        echo "✅ Verified: $NEW_VIDEO video-only, $NEW_AUDIO audio-only bots in compose file"
    else
        echo "⚠️  Warning: Verification failed. Expected $VIDEO_COUNT video, $AUDIO_COUNT audio"
        echo "   Found: $NEW_VIDEO video, $NEW_AUDIO audio"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Successfully scaled bots!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "  Previous: $CURRENT_VIDEO video-only, $CURRENT_AUDIO audio-only (Total: $CURRENT_TOTAL)"
echo "  Added:    +$VIDEO_TO_ADD video-only, +$AUDIO_TO_ADD audio-only (Total: +$ADDED)"
echo "  Current:  $VIDEO_COUNT video-only, $AUDIO_COUNT audio-only (Total: $TOTAL_BOTS)"
echo "  Capacity: $SUM_COUNTS used, $((TOTAL_BOTS - SUM_COUNTS)) available for future scaling"
echo ""
echo "💡 Next steps:"
echo "  1. Check resources: ./check-server-resources.sh"
echo "  2. Test with a few bots: docker compose -f $COMPOSE_FILE up bot-$((CURRENT_TOTAL + 1)) bot-$((CURRENT_TOTAL + 2))"
echo "  3. Run all bots: docker compose -f $COMPOSE_FILE up -d"
echo "  4. Monitor: docker stats"
echo ""

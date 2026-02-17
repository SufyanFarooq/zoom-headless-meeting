#!/bin/bash

# setup-flexible-bots.sh - Create and start Zoom bots using Docker Compose
# Usage: setup-flexible-bots.sh <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret> [meeting_id] [request_id] [timeout_seconds]

set -e  # Exit on any error

# Get arguments
VIDEO_COUNT="$1"
AUDIO_COUNT="$2"
JOIN_URL="$3"
ACCOUNT_ID="$4"
CLIENT_ID="$5"
CLIENT_SECRET="$6"

# Get environment variables (with fallbacks)
HOST_PROJECT_PATH="${HOST_PROJECT_PATH:-/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample}"
PROJECT_MOUNT_MODE="${PROJECT_MOUNT_MODE:-rw}"
MEETING_TYPE="${MEETING_TYPE:-Normal Member}"
NAME_TYPE="${NAME_TYPE:-Indian}"
MEETING_ID="${MEETING_ID:-${7:-}}"
REQUEST_ID="${REQUEST_ID:-${8:-}}"
NAME_OFFSET="${NAME_OFFSET:-0}"
BOT_PREBUILT_RUNTIME="${BOT_PREBUILT_RUNTIME:-true}"
# Timeout: arg 9 takes precedence (reliable in Docker), else env, else default 7200
TIMEOUT_SECONDS="${9:-${TIMEOUT_SECONDS:-7200}}"
# Ensure it's a valid number
if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_SECONDS" -le 0 ]; then
  TIMEOUT_SECONDS=7200
fi
echo "⏱️  Bot timeout: ${TIMEOUT_SECONDS}s (bots will leave meeting after this)"

# Validate required arguments
if [ -z "$VIDEO_COUNT" ] || [ -z "$AUDIO_COUNT" ] || [ -z "$JOIN_URL" ]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: $0 <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret>"
    exit 1
fi

# Validate counts are numbers
if ! [[ "$VIDEO_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$AUDIO_COUNT" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: video_count and audio_count must be numbers"
    exit 1
fi

# Validate MEETING_ID and REQUEST_ID
if [ -z "$MEETING_ID" ] || [ -z "$REQUEST_ID" ]; then
    echo "❌ Error: MEETING_ID and REQUEST_ID environment variables are required"
    exit 1
fi

TOTAL_BOTS=$((VIDEO_COUNT + AUDIO_COUNT))

if [ "$TOTAL_BOTS" -eq 0 ]; then
    echo "❌ Error: Total bots (video + audio) cannot be 0"
    exit 1
fi

echo "🤖 Setting up $TOTAL_BOTS bots ($VIDEO_COUNT video, $AUDIO_COUNT audio)"
echo "📋 Meeting ID: $MEETING_ID"
echo "📋 Request ID: $REQUEST_ID"
echo "📋 Meeting Type: $MEETING_TYPE"
echo "📋 Name Type: $NAME_TYPE"
echo "📋 Join URL: $JOIN_URL"
echo "📋 Name Offset: $NAME_OFFSET"
if [ "$BOT_PREBUILT_RUNTIME" = "true" ] || [ "$BOT_PREBUILT_RUNTIME" = "1" ]; then
    echo "📋 Runtime: prebuilt binary"
else
    echo "📋 Runtime: dynamic build (legacy)"
fi

# Generate unique compose file name
COMPOSE_FILE="compose-${MEETING_ID}-${REQUEST_ID}-bots.yaml"
echo "📄 Compose file: $COMPOSE_FILE"

# Function to generate ZAK token for a bot
# Uses /users/{userId}/token?type=zak (2h validity) - more reliable than /users/{email}/zak
generate_zak_token() {
    local email="$1"
    local account_id="$2"
    local client_id="$3"
    local client_secret="$4"

    if [ -z "$email" ]; then
        echo "mock_zak_token_no_email_$(date +%s)"
        return 0
    fi

    # First get access token using OAuth (Server-to-Server)
    echo "🔑 Getting access token for ZAK generation..." >&2

    local token_response=$(curl -s -X POST "https://zoom.us/oauth/token" \
        -H "Authorization: Basic $(echo -n "$client_id:$client_secret" | base64)" \
        -d "grant_type=account_credentials&account_id=$account_id")

    local access_token=$(echo "$token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
        echo "❌ Failed to get access token" >&2
        echo "$token_response" >&2
        echo "mock_zak_token_no_access_$(date +%s)"
        return 1
    fi

    # Resolve email to user ID (Zoom API needs userId for ZAK, not email)
    echo "🔑 Getting ZAK token for $email..." >&2
    local user_response=$(curl -s -X GET "https://api.zoom.us/v2/users/$(echo "$email" | sed 's/@/%40/g')" \
        -H "Authorization: Bearer $access_token")
    local user_id=$(echo "$user_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -z "$user_id" ]; then
        user_id="$email"
    fi

    # Use token?type=zak (2h validity) - /zak endpoint gives 5min and may not work with S2S
    local zak_response=$(curl -s -X GET "https://api.zoom.us/v2/users/$user_id/token?type=zak" \
        -H "Authorization: Bearer $access_token")

    local zak_token=$(echo "$zak_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$zak_token" ] || [ "$zak_token" = "null" ]; then
        echo "❌ Failed to get ZAK token for $email" >&2
        echo "$zak_response" >&2
        if echo "$zak_response" | grep -q '"code":2300'; then
            echo "💡 Tip: ZAK may require OAuth 2.0 (User OAuth). Use ZOOM_REFRESH_TOKEN in .env for ZAK pre-generate job." >&2
        fi
        echo "mock_zak_token_failed_$(date +%s)"
        return 1
    fi

    echo "$zak_token"
}

# Function to get display name from names file
get_display_name() {
    local bot_num=$1
    local name_offset=${NAME_OFFSET:-0}
    local actual_line_num=$((bot_num + name_offset))
    local name=""

    # Select names file: profile-pics/names/Type.txt, fallback to legacy paths
    local names_file=""
    if [ -d "profile-pics/names" ] && [ -f "profile-pics/names/${NAME_TYPE}.txt" ]; then
        names_file="profile-pics/names/${NAME_TYPE}.txt"
    elif [ "$NAME_TYPE" = "Indian" ] || [ "$NAME_TYPE" = "indian" ]; then
        names_file="profile-pics/names.txt"
    elif [ "$NAME_TYPE" = "International" ] || [ "$NAME_TYPE" = "international" ]; then
        names_file="profile-pics/names-international.txt"
    else
        names_file="profile-pics/names.txt"
    fi

    # Read name from names file
    if [ -f "$names_file" ]; then
        local total_lines=$(wc -l < "$names_file" 2>/dev/null | tr -d ' ' || echo "0")
        if [ "$total_lines" -gt 0 ]; then
            local line_to_read=$((actual_line_num % total_lines))
            if [ "$line_to_read" -eq 0 ]; then
                line_to_read=$total_lines
            fi
            name=$(sed -n "${line_to_read}p" "$names_file" 2>/dev/null | xargs)
        fi

        # Skip empty lines and comments
        if [ -z "$name" ] || [[ "$name" =~ ^# ]]; then
            name=""
        fi
    fi

    # Fallback to Bot-number
    if [ -z "$name" ]; then
        name="Bot-${actual_line_num}"
    fi

    echo "$name"
}

# Optional override for video input (e.g., TEST_PATTERN). If empty, fall back to videos/video-N.mp4
VIDEO_FILE_OVERRIDE="${VIDEO_FILE:-}"
VIDEO_DEVICE_BASE="${VIDEO_DEVICE_BASE:-2}"
CAMERA_LABEL_PREFIX="${CAMERA_LABEL_PREFIX:-BotCam}"
CAMERA_MODE="${CAMERA_MODE:-v4l2}"
AUDIO_CAMERA_LABEL="${AUDIO_CAMERA_LABEL:-}"
AUDIO_DEVICE_INDEX="${AUDIO_DEVICE_INDEX:-1}"
AUDIO_VIDEO_ICON_ONLY="${AUDIO_VIDEO_ICON_ONLY:-true}"
AUDIO_DEVICE_BASE="${AUDIO_DEVICE_BASE:-$VIDEO_DEVICE_BASE}"
AUDIO_CAMERA_LABEL_PREFIX="${AUDIO_CAMERA_LABEL_PREFIX:-BotCamAudio}"
AUDIO_USE_CAMERA="${AUDIO_USE_CAMERA:-true}"
AUDIO_DEVICE_COUNT="${AUDIO_DEVICE_COUNT:-0}"
AUDIO_DIRECT_OFF_JOIN="${AUDIO_DIRECT_OFF_JOIN:-false}"
SDK_JWT_TOKEN="${SDK_JWT_TOKEN:-}"
VIDEO_CPU_LIMIT="${VIDEO_CPU_LIMIT:-0.3}"
AUDIO_CPU_LIMIT="${AUDIO_CPU_LIMIT:-0.1}"
VIDEO_MEM_LIMIT="${VIDEO_MEM_LIMIT:-512M}"
AUDIO_MEM_LIMIT="${AUDIO_MEM_LIMIT:-256M}"
VIDEO_CPU_RESERVATION="${VIDEO_CPU_RESERVATION:-0.05}"
AUDIO_CPU_RESERVATION="${AUDIO_CPU_RESERVATION:-0.02}"
VIDEO_MEM_RESERVATION="${VIDEO_MEM_RESERVATION:-256M}"
AUDIO_MEM_RESERVATION="${AUDIO_MEM_RESERVATION:-128M}"

# Create services section for docker-compose
create_compose_services() {
    local bot_num="$1"
    local bot_type="$2"  # "video" or "audio"
    local video_idx="$3"
    local audio_idx="$4"

    local container_name="zoom-bot-${MEETING_ID}-${REQUEST_ID}-${bot_num}"
    local service_name="bot-${MEETING_ID}-${REQUEST_ID}-${bot_num}"
    local display_name=$(get_display_name $bot_num)
    local cpu_limit=""
    local mem_limit=""
    local cpu_res=""
    local mem_res=""
    local entry_script="./bin/entry-bot-optimized.sh"
    local build_cache_volume="      - \"/tmp/build-cache:/tmp/meeting-sdk-linux-sample/build\""
    local sdk_jwt_env=""

    if [ "$BOT_PREBUILT_RUNTIME" = "true" ] || [ "$BOT_PREBUILT_RUNTIME" = "1" ]; then
        entry_script="/opt/zoomsdk-runtime/entry-bot-runtime.sh"
        build_cache_volume=""
    fi

    if [ -n "$SDK_JWT_TOKEN" ]; then
        sdk_jwt_env="      - ZOOM_SDK_JWT=${SDK_JWT_TOKEN}"
    fi

    if [ "$bot_type" = "video" ]; then
        cpu_limit="$VIDEO_CPU_LIMIT"
        mem_limit="$VIDEO_MEM_LIMIT"
        cpu_res="$VIDEO_CPU_RESERVATION"
        mem_res="$VIDEO_MEM_RESERVATION"
    else
        cpu_limit="$AUDIO_CPU_LIMIT"
        mem_limit="$AUDIO_MEM_LIMIT"
        cpu_res="$AUDIO_CPU_RESERVATION"
        mem_res="$AUDIO_MEM_RESERVATION"
    fi

    # Determine video/audio config - each arg must be a separate YAML list item for zoomsdk
    local camera_args=""
    local video_args=""
    local device_block=""
    if [ "$bot_type" = "video" ]; then
        if [ "$CAMERA_MODE" = "raw" ]; then
            local video_num=$(( (bot_num - 1) % 100 + 1 ))
            local video_input="${VIDEO_FILE_OVERRIDE:-videos/video-${video_num}.mp4}"
            video_args="      - RawVideo
      - --input
      - ${video_input}"
        else
            local device_index=$((VIDEO_DEVICE_BASE + video_idx - 1))
            local camera_label="${CAMERA_LABEL_PREFIX}${video_idx}"
            device_block="    devices:
      - \"/dev/video${device_index}:/dev/video${device_index}\""
            camera_args="      - --camera-mode
      - v4l2
      - --camera-name
      - ${camera_label}"
        fi
    else
        # Audio-only: RawAudio only, optionally use camera to register icon
        video_args="      - RawAudio
      - --file
      - dev-null.pcm
      - --dir
      - \"/dev\""
        if [ "$AUDIO_DIRECT_OFF_JOIN" = "true" ] || [ "$AUDIO_DIRECT_OFF_JOIN" = "1" ]; then
            # Fast path: join with audio/video off only, no camera/icon registration.
            camera_args=""
            device_block=""
        else
            if [ "$AUDIO_USE_CAMERA" = "true" ] || [ "$AUDIO_USE_CAMERA" = "1" ]; then
                if [ -n "$AUDIO_CAMERA_LABEL" ]; then
                    local audio_device_index=$((AUDIO_DEVICE_BASE + AUDIO_DEVICE_INDEX - 1))
                    device_block="    devices:
      - \"/dev/video${audio_device_index}:/dev/video${audio_device_index}\""
                    camera_args="      - --camera-mode
      - v4l2
      - --camera-name
      - ${AUDIO_CAMERA_LABEL}"
                else
                    local audio_slot=$audio_idx
                    if [ "$AUDIO_DEVICE_COUNT" -gt 0 ]; then
                        audio_slot=$(( (audio_idx - 1) % AUDIO_DEVICE_COUNT + 1 ))
                    fi
                    local audio_device_index=$((AUDIO_DEVICE_BASE + audio_slot - 1))
                    local audio_label="${AUDIO_CAMERA_LABEL_PREFIX}${audio_slot}"
                    device_block="    devices:
      - \"/dev/video${audio_device_index}:/dev/video${audio_device_index}\""
                    camera_args="      - --camera-mode
      - v4l2
      - --camera-name
      - ${audio_label}"
                fi
            fi
            if [ "$AUDIO_VIDEO_ICON_ONLY" = "true" ] || [ "$AUDIO_VIDEO_ICON_ONLY" = "1" ]; then
                camera_args="$camera_args
      - --video-icon-only"
            fi
        fi
    fi

    cat << EOF
  $service_name:
    image: zoom-bot:latest
    container_name: $container_name
    volumes:
      - "$HOST_PROJECT_PATH:/tmp/meeting-sdk-linux-sample:${PROJECT_MOUNT_MODE}"
${build_cache_volume}
    environment:
      - DISPLAY_NAME=$display_name
      - JOIN_URL=$JOIN_URL
      - TIMEOUT_SECONDS=$TIMEOUT_SECONDS
      - ZOOM_AUTH_RETRIES=${ZOOM_AUTH_RETRIES:-2}
${sdk_jwt_env}
      - AUDIO_DIRECT_OFF_JOIN=${AUDIO_DIRECT_OFF_JOIN}
      - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
      - QT_QPA_PLATFORM=offscreen
      - DISPLAY=:99
      - G_MESSAGES_DEBUG=
    working_dir: /tmp/meeting-sdk-linux-sample
    entrypoint:
      - /tini
      - --
      - ${entry_script}
    command:
      - --join-url
      - $JOIN_URL
      - --display-name
      - $display_name
      - --config
      - config.toml
$camera_args
$video_args
${device_block}
    cpus: "${cpu_limit}"
    mem_limit: ${mem_limit}
    mem_reservation: ${mem_res}
    deploy:
      resources:
        limits:
          cpus: '${cpu_limit}'
          memory: ${mem_limit}
        reservations:
          cpus: '${cpu_res}'
          memory: ${mem_res}
    stop_grace_period: 2s
    restart: 'no'
EOF
}

# Use meeting ID + request ID for unique compose file name
# This ensures each bot creation request gets its own compose file
COMPOSE_FILE="compose-${MEETING_ID}-${REQUEST_ID}-bots.yaml"
TEMP_FILE="${COMPOSE_FILE}.tmp"

# Start compose file
cat > "$TEMP_FILE" << 'EOF'
version: '3.8'

networks:
  zoom-bots:
    driver: bridge

services:
EOF

echo "📝 Generating compose file with:"
echo "   - Video-only bots: $VIDEO_COUNT"
echo "   - Audio-only bots: $AUDIO_COUNT"
echo "   - Total bots: $TOTAL_BOTS"

BOT_NUMBER=1
VIDEO_BOT_INDEX=0
AUDIO_BOT_INDEX=0

# Generate Video-only bots
if [ $VIDEO_COUNT -gt 0 ]; then
    echo "📹 Generating $VIDEO_COUNT video-only bots..."
    for i in $(seq 1 $VIDEO_COUNT); do
        VIDEO_BOT_INDEX=$((VIDEO_BOT_INDEX + 1))
        create_compose_services "$BOT_NUMBER" "video" "$VIDEO_BOT_INDEX" "" >> "$TEMP_FILE"
        BOT_NUMBER=$((BOT_NUMBER + 1))
    done
fi

# Generate Audio-only bots
if [ $AUDIO_COUNT -gt 0 ]; then
    echo "🔊 Generating $AUDIO_COUNT audio-only bots..."
    for i in $(seq 1 $AUDIO_COUNT); do
        AUDIO_BOT_INDEX=$((AUDIO_BOT_INDEX + 1))
        create_compose_services "$BOT_NUMBER" "audio" "" "$AUDIO_BOT_INDEX" >> "$TEMP_FILE"
        BOT_NUMBER=$((BOT_NUMBER + 1))
    done
fi

if [ "$BOT_PREBUILT_RUNTIME" != "true" ] && [ "$BOT_PREBUILT_RUNTIME" != "1" ]; then
cat >> "$TEMP_FILE" << 'EOF'

volumes:
  build-cache:
EOF
fi

# Replace original file
rm -f "$COMPOSE_FILE"
mv "$TEMP_FILE" "$COMPOSE_FILE"

echo "✅ Generated $COMPOSE_FILE with $TOTAL_BOTS bots"
echo "   - Video-only: $VIDEO_COUNT"
echo "   - Audio-only: $AUDIO_COUNT"

# Step 2: Generate ZAK tokens for Profile Pic Member meetings
MEETING_TYPE="${MEETING_TYPE:-Normal Member}"
MEETING_TYPE_NORMALIZED=$(echo "$MEETING_TYPE" | xargs)

if [ "$MEETING_TYPE_NORMALIZED" = "Profile Pic Member" ]; then
    echo ""
    echo "🔑 Step 2: ZAK tokens for Profile Pic Member meeting..."

    USERS_FILE="${USERS_FILE:-profile-pics/users.txt}"
    ZAK_CACHE_MINUTES="${ZAK_CACHE_MINUTES:-60}"
    USE_SINGLE_ZAK="${USE_SINGLE_ZAK:-false}"

    if [ -f "$USERS_FILE" ] && [ -s "$USERS_FILE" ]; then
        EMAIL_COUNT=$(wc -l < "$USERS_FILE" | tr -d ' ')
        NAME_OFFSET="${NAME_OFFSET:-0}"
        REMAINING=$((EMAIL_COUNT - NAME_OFFSET))
        if [ "$REMAINING" -lt 0 ]; then REMAINING=0; fi
        BOTS_NEEDING_ZAK=$((REMAINING < TOTAL_BOTS ? REMAINING : TOTAL_BOTS))
        if [ "$BOTS_NEEDING_ZAK" -le 0 ]; then
            echo "   ℹ️  No emails remaining for ZAK (offset=$NAME_OFFSET, total_emails=$EMAIL_COUNT) - bots will join as guests"
            rm -f bot-zak-tokens.env
        else

        # 1) Pre-generated ZAK (from bot-server job every 2h) - fastest
        PRELOAD_FILE="${ZAK_PRELOAD_FILE:-zak-token.env}"
        CACHE_VALID=false
        # NAME_OFFSET: 2nd batch needs BOT11..BOT20 (not BOT1..BOT10)
        START_IDX=$((NAME_OFFSET + 1))
        END_IDX=$((NAME_OFFSET + BOTS_NEEDING_ZAK))

        if [ -f "$PRELOAD_FILE" ]; then
            CACHE_MTIME=$(stat -c %Y "$PRELOAD_FILE" 2>/dev/null || stat -f %m "$PRELOAD_FILE" 2>/dev/null)
            CACHE_AGE=$(( ($(date +%s) - ${CACHE_MTIME:-0}) / 60 ))
            if [ "$CACHE_AGE" -lt 90 ]; then
                PRELOAD_COUNT=$(grep -cE '^BOT[0-9]+_ZAK_TOKEN=' "$PRELOAD_FILE" 2>/dev/null || echo 0)
                PRELOAD_ZAK=$(grep -E '^ZAK_TOKEN=' "$PRELOAD_FILE" 2>/dev/null | cut -d= -f2-)
                if [ -z "$PRELOAD_ZAK" ]; then
                    PRELOAD_ZAK=$(grep -E '^BOT1_ZAK_TOKEN=' "$PRELOAD_FILE" 2>/dev/null | cut -d= -f2-)
                fi
                if [ "$PRELOAD_COUNT" -ge "$START_IDX" ]; then
                    TOKEN_END=$END_IDX
                    if [ "$PRELOAD_COUNT" -lt "$END_IDX" ]; then
                        TOKEN_END=$PRELOAD_COUNT
                    fi
                    echo "# From pre-generated $PRELOAD_FILE ($CACHE_AGE min old, offset=$NAME_OFFSET → BOT${START_IDX}..BOT${END_IDX})" > bot-zak-tokens.env
                    for i in $(seq $START_IDX $TOKEN_END); do
                        line=$(grep -E "^BOT${i}_ZAK_TOKEN=" "$PRELOAD_FILE" 2>/dev/null)
                        [ -n "$line" ] && echo "$line" >> bot-zak-tokens.env
                    done
                    if [ $(grep -cE '^BOT[0-9]+_ZAK_TOKEN=' bot-zak-tokens.env 2>/dev/null) -gt 0 ]; then
                        if [ "$TOKEN_END" -lt "$END_IDX" ]; then
                            echo "   ✅ Using pre-generated ZAK from $PRELOAD_FILE (${CACHE_AGE}m old) for BOT${START_IDX}..BOT${TOKEN_END}; remaining bots join as guests"
                        else
                            echo "   ✅ Using pre-generated ZAK from $PRELOAD_FILE (${CACHE_AGE}m old, per-bot profile pics)"
                        fi
                        CACHE_VALID=true
                    fi
                fi
                if [ "$CACHE_VALID" = false ] && { [ "$USE_SINGLE_ZAK" = "true" ] || [ "$USE_SINGLE_ZAK" = "1" ]; }; then
                    if [ -n "$PRELOAD_ZAK" ] && [ ${#PRELOAD_ZAK} -gt 50 ]; then
                        echo "# From pre-generated $PRELOAD_FILE ($CACHE_AGE min old, 1 ZAK for all, offset=$NAME_OFFSET)" > bot-zak-tokens.env
                        for i in $(seq $START_IDX $END_IDX); do echo "BOT${i}_ZAK_TOKEN=$PRELOAD_ZAK" >> bot-zak-tokens.env; done
                        echo "   ✅ Using pre-generated ZAK from $PRELOAD_FILE (1 token - same profile pic for all)"
                        CACHE_VALID=true
                    fi
                fi
            fi
        fi

        # 2) Check cache: reuse bot-zak-tokens.env if recent (only when NAME_OFFSET=0 - cached file has BOT1..BOT10)
        if [ "$CACHE_VALID" = false ] && [ -f "bot-zak-tokens.env" ] && [ "$NAME_OFFSET" -eq 0 ]; then
            CACHE_MTIME=$(stat -c %Y bot-zak-tokens.env 2>/dev/null || stat -f %m bot-zak-tokens.env 2>/dev/null)
            CACHE_AGE=$(( ($(date +%s) - ${CACHE_MTIME:-0}) / 60 ))
            CACHED_COUNT=$(grep -c "BOT[0-9]*_ZAK_TOKEN=" bot-zak-tokens.env 2>/dev/null || echo 0)
            if [ "$CACHE_AGE" -lt "$ZAK_CACHE_MINUTES" ] && [ "$CACHED_COUNT" -ge "$BOTS_NEEDING_ZAK" ]; then
                CACHE_VALID=true
                echo "   ✅ Using cached ZAK tokens (${CACHE_AGE}m old) - skipping generation"
            fi
        fi

        if [ "$CACHE_VALID" = false ]; then
            echo "   Found $EMAIL_COUNT emails, generating ZAK tokens for $BOTS_NEEDING_ZAK bots..."

            # Single ZAK: 1 token for all bots (fast - 1 API call)
            if [ "$USE_SINGLE_ZAK" = "true" ] || [ "$USE_SINGLE_ZAK" = "1" ]; then
                echo "   💡 USE_SINGLE_ZAK=true - generating 1 token, reusing for all bots"
                FIRST_EMAIL=$(head -1 "$USERS_FILE" | awk '{print $1}')
                SINGLE_ZAK=$(generate_zak_token "$FIRST_EMAIL" "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET")
                echo "# Single ZAK for all bots (generated $(date), offset=$NAME_OFFSET)" > bot-zak-tokens.env
                for i in $(seq $START_IDX $END_IDX); do
                    echo "BOT${i}_ZAK_TOKEN=$SINGLE_ZAK" >> bot-zak-tokens.env
                done
                echo "   ✅ Generated 1 ZAK token, applied to $BOTS_NEEDING_ZAK bots"
            else
                # Create temporary users file with only the emails we need
                # Respect NAME_OFFSET so refill uses next accounts (no wrap)
                TEMP_USERS_FILE=$(mktemp)
                TOTAL_LINES="${EMAIL_COUNT:-0}"
                OFFSET="${NAME_OFFSET:-0}"
                if [ "$TOTAL_LINES" -gt 0 ] && [ "$OFFSET" -lt "$TOTAL_LINES" ] && [ "$BOTS_NEEDING_ZAK" -gt 0 ]; then
                    START_LINE=$((OFFSET + 1))
                    tail -n +$START_LINE "$USERS_FILE" | head -n "$BOTS_NEEDING_ZAK" > "$TEMP_USERS_FILE"
                else
                    : > "$TEMP_USERS_FILE"
                fi

                # Use parallel generation
                PARALLEL_JOBS=0
                if [ $BOTS_NEEDING_ZAK -ge 5 ]; then
                    if [ $BOTS_NEEDING_ZAK -ge 100 ]; then
                        PARALLEL_JOBS=50
                    elif [ $BOTS_NEEDING_ZAK -ge 50 ]; then
                        PARALLEL_JOBS=30
                    elif [ $BOTS_NEEDING_ZAK -ge 20 ]; then
                        PARALLEL_JOBS=20
                    else
                        PARALLEL_JOBS=10
                    fi
                    echo "   💡 Using parallel ZAK generation ($PARALLEL_JOBS jobs)"
                fi

                # Set COMPOSE_FILE environment variable
                COMPOSE_FILE_NAME="compose-${MEETING_ID}-${REQUEST_ID}-bots.yaml"
                export COMPOSE_FILE="$COMPOSE_FILE_NAME"

                if ./auto-setup-bots.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" "$TEMP_USERS_FILE" "$PARALLEL_JOBS"; then
                    echo "   ✅ ZAK tokens generated successfully"
                else
                    echo "   ❌ Error: Failed to generate ZAK tokens"
                    rm -f "$TEMP_USERS_FILE"
                    exit 1
                fi
                rm -f "$TEMP_USERS_FILE"
            fi
        fi

        # Add ZAK tokens to compose file (from cache or fresh generation)
        # NAME_OFFSET ensures 2nd batch for same meeting gets BOT11, BOT12... (not BOT1, BOT2...)
        COMPOSE_FILE_NAME="compose-${MEETING_ID}-${REQUEST_ID}-bots.yaml"
        COMPOSE_PATH="$(pwd)/$COMPOSE_FILE_NAME"
        if [ -f "bot-zak-tokens.env" ] && grep -qE '^BOT[0-9]+_ZAK_TOKEN=' bot-zak-tokens.env 2>/dev/null && [ -f "$COMPOSE_FILE_NAME" ]; then
            echo ""
            echo "🔄 Adding ZAK tokens to compose file (NAME_OFFSET=${NAME_OFFSET:-0})..."
            if NAME_OFFSET="${NAME_OFFSET:-0}" python3 update-compose-zak.py "$COMPOSE_PATH"; then
                echo "   ✅ ZAK tokens added to compose file"
            else
                echo "   ⚠️  Python script failed, but tokens may still be in file"
            fi
        fi
        fi
    else
        echo "   ⚠️  Users file not found or empty - skipping ZAK token generation"
    fi
else
    echo ""
    echo "ℹ️  Meeting type is '$MEETING_TYPE' - skipping ZAK token generation"
fi

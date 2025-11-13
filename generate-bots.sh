#!/bin/bash

# Smart script to generate and run multiple bots with different names
# Usage: ./generate-bots.sh [number-of-bots] [meeting-url]

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

echo "🚀 Generating $NUM_BOTS bots..."

# Create docker-compose file dynamically
cat > compose-50-bots.yaml << EOF
services:
EOF

for i in $(seq 1 $NUM_BOTS); do
    BOT_NUM=$i
    # Use modulo to cycle through names if more than 50 bots
    NAME_INDEX=$(( (i - 1) % ${#BOT_NAMES[@]} ))
    BOT_NAME="${BOT_NAMES[$NAME_INDEX]}"
    FULL_NAME="Bot-${BOT_NUM}-${BOT_NAME}"
    
    cat >> compose-50-bots.yaml << EOF
  bot-${BOT_NUM}:
    build: ./
    platform: linux/amd64
    container_name: zoom-bot-${BOT_NUM}
    volumes:
     - .:/tmp/meeting-sdk-linux-sample
     - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
     - DISPLAY_NAME=${FULL_NAME}
     - JOIN_URL=${JOIN_URL}
     - CLIENT_ID=${CLIENT_ID}
     - CLIENT_SECRET=${CLIENT_SECRET}
     - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
     - QT_QPA_PLATFORM=offscreen
     - G_MESSAGES_DEBUG=
    entrypoint: ["/tini", "--", "./bin/entry-bot-optimized.sh"]
    command:
      - "--client-id"
      - "${CLIENT_ID}"
      - "--client-secret"
      - "${CLIENT_SECRET}"
      - "--join-url"
      - "${JOIN_URL}"
      - "--display-name"
      - "${FULL_NAME}"
      - "--config"
      - "config.toml"
      - "RawVideo"
      - "--input"
      - "input-video.mp4"
    deploy:
      resources:
        limits:
          cpus: '0.6'      # Optimized: was 1.0, actual usage ~0.5
          memory: 256M     # Optimized: was 2G, actual usage ~128MB
        reservations:
          cpus: '0.1'      # Optimized: was 0.2
          memory: 128M     # Optimized: was 512M
    restart: no

EOF
done

cat >> compose-50-bots.yaml << EOF
volumes:
  build-cache:
EOF

echo "✅ Generated compose-50-bots.yaml with $NUM_BOTS bots"
echo ""
echo "🚀 To run all bots:"
echo "   docker compose -f compose-50-bots.yaml up -d"
echo ""
echo "🛑 To stop all bots:"
echo "   docker compose -f compose-50-bots.yaml down"


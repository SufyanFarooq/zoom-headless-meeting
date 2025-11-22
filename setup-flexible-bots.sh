#!/bin/bash

# Setup flexible bots with ZAK token generation
# Usage: ./setup-flexible-bots.sh <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret> [users_file]

set -e

VIDEO_COUNT=${1:-0}
AUDIO_COUNT=${2:-0}
JOIN_URL=${3:-""}
ACCOUNT_ID=${4:-""}
CLIENT_ID=${5:-""}
CLIENT_SECRET=${6:-""}
USERS_FILE=${7:-"profile-pics/users.txt"}

if [ -z "$JOIN_URL" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ Error: Missing required arguments"
    echo ""
    echo "Usage:"
    echo "  ./setup-flexible-bots.sh <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret> [users_file]"
    echo ""
    echo "Example:"
    echo "  ./setup-flexible-bots.sh 6 4 'https://zoom.us/j/xxx' kOjrXedBRwGlbGiCyzQOyQ vdPX1q2bSQKip0X17LqXAw Te1YdXaBL6IScwdBVlNF0kay75KDMkyz"
    echo ""
    echo "This will create:"
    echo "  - 6 video-only bots"
    echo "  - 4 audio-only bots"
    exit 1
fi

TOTAL_BOTS=$((VIDEO_COUNT + AUDIO_COUNT))

if [ $TOTAL_BOTS -eq 0 ]; then
    echo "❌ Error: At least one bot type must be specified"
    exit 1
fi

echo "🚀 Setting up flexible bots..."
echo "   - Video-only: $VIDEO_COUNT"
echo "   - Audio-only: $AUDIO_COUNT"
echo "   - Total: $TOTAL_BOTS"

# Step 1: Generate compose file
echo ""
echo "📝 Step 1: Generating compose file..."
./generate-flexible-bots.sh "$VIDEO_COUNT" "$AUDIO_COUNT" "$JOIN_URL" "Bot" "$USERS_FILE"

# Step 2: Generate ZAK tokens for bots with emails
if [ -f "$USERS_FILE" ] && [ -s "$USERS_FILE" ]; then
    echo ""
    echo "🔑 Step 2: Generating ZAK tokens..."
    
    # Count how many emails we have
    EMAIL_COUNT=$(wc -l < "$USERS_FILE" | tr -d ' ')
    
    if [ $EMAIL_COUNT -gt 0 ] && [ $EMAIL_COUNT -le $TOTAL_BOTS ]; then
        echo "   Found $EMAIL_COUNT emails in $USERS_FILE"
        echo "   Generating ZAK tokens for first $EMAIL_COUNT bots..."
        
        # Call auto-setup-bots.sh with the ZAK token generation parameters
        # auto-setup-bots.sh expects: <account_id> <client_id> <client_secret> [users_file]
        ./auto-setup-bots.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" "$USERS_FILE"
        
        # Ensure ZAK tokens are added to compose file using update-compose-zak.py
        # This is a fallback in case auto-setup-bots.sh didn't properly update the file
        echo ""
        echo "🔄 Verifying ZAK tokens in compose file..."
        if [ -f "bot-zak-tokens.env" ]; then
            python3 update-compose-zak.py
        fi
    else
        echo "⚠️  Warning: Email count ($EMAIL_COUNT) doesn't match bot count ($TOTAL_BOTS)"
        echo "   Bots without emails will join as guests"
    fi
else
    echo ""
    echo "⚠️  Step 2: No users file found or file is empty"
    echo "   Bots will join as guests without ZAK tokens"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start bots, run:"
echo "   docker compose -f compose-50-bots.yaml up -d"
echo ""
echo "To start specific bots:"
echo "   docker compose -f compose-50-bots.yaml up bot-1 bot-2 ..."


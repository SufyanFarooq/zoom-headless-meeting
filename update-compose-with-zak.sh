#!/bin/bash

# Script to update compose file with ZAK tokens from bot-zak-tokens.env
# Uses Python script if available, otherwise uses sed

set -e

COMPOSE_FILE="compose-50-bots.yaml"
TOKENS_FILE="bot-zak-tokens.env"

if [ ! -f "$TOKENS_FILE" ]; then
    echo "❌ Tokens file not found: $TOKENS_FILE"
    echo "💡 Run auto-setup-bots.sh first to generate tokens"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    exit 1
fi

echo "🔄 Updating compose file with ZAK tokens..."
echo ""

# Try Python script first (more reliable)
if command -v python3 > /dev/null 2>&1 && [ -f "update-compose-zak.py" ]; then
    echo "Using Python script (more reliable)..."
    python3 update-compose-zak.py
    exit $?
fi

# Fallback to bash/sed method
echo "Using bash script..."

# Read tokens from file
source "$TOKENS_FILE" 2>/dev/null || true

# Update each bot
BOT_NUM=1
UPDATED=0

while true; do
    TOKEN_VAR="BOT${BOT_NUM}_ZAK_TOKEN"
    EMAIL_VAR="BOT${BOT_NUM}_EMAIL"
    
    TOKEN_VALUE="${!TOKEN_VAR}"
    EMAIL_VALUE="${!EMAIL_VAR}"
    
    if [ -z "$TOKEN_VALUE" ]; then
        break  # No more bots
    fi
    
    echo "Processing Bot $BOT_NUM: $EMAIL_VALUE"
    
    # Check if ZAK already exists
    if grep -A 20 "bot-${BOT_NUM}:" "$COMPOSE_FILE" | grep -q "\"--zak\""; then
        echo "  ℹ️  ZAK token already exists (skipping)"
    else
        # Add ZAK token after --config config.toml using awk (more reliable than sed)
        awk -v bot_num="$BOT_NUM" -v zak_token="$TOKEN_VALUE" '
        /^  bot-' bot_num ':/ { in_bot=1 }
        in_bot && /config\.toml/ { 
            print
            getline
            print "      - \"--zak\""
            print "      - \"" zak_token "\""
            in_bot=0
        }
        !in_bot || !/config\.toml/ { print }
        ' "$COMPOSE_FILE" > "${COMPOSE_FILE}.tmp" && mv "${COMPOSE_FILE}.tmp" "$COMPOSE_FILE"
        
        echo "  ✅ Added ZAK token"
        UPDATED=$((UPDATED + 1))
    fi
    
    BOT_NUM=$((BOT_NUM + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Compose file updated! ($UPDATED bots updated)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Test:"
echo "   docker compose -f $COMPOSE_FILE up --build bot-1"


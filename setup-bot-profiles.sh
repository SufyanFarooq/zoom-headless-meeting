#!/bin/bash

# Complete setup script for bot profile pictures
# This script:
# 1. Uploads profile pictures to Zoom accounts
# 2. Generates ZAK tokens for each account
# 3. Creates a tokens file for use in compose

set -e

if [ $# -lt 4 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> <profile_pics_dir>"
    echo ""
    echo "Example:"
    echo "  $0 YOUR_ACCOUNT_ID YOUR_CLIENT_ID YOUR_CLIENT_SECRET ./profile-pics"
    echo ""
    echo "Profile pics directory should contain:"
    echo "  - bot1.jpg (or bot1.png)"
    echo "  - bot2.jpg (or bot2.png)"
    echo "  - etc."
    echo ""
    echo "And a users.txt file with:"
    echo "  bot1@example.com"
    echo "  bot2@example.com"
    echo "  etc."
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
PROFILE_PICS_DIR="$4"

if [ ! -d "$PROFILE_PICS_DIR" ]; then
    echo "❌ Error: Profile pics directory not found: $PROFILE_PICS_DIR"
    exit 1
fi

USERS_FILE="$PROFILE_PICS_DIR/users.txt"
if [ ! -f "$USERS_FILE" ]; then
    echo "❌ Error: users.txt not found in $PROFILE_PICS_DIR"
    echo "Create users.txt with one email per line"
    exit 1
fi

echo "🚀 Setting up bot profile pictures..."
echo ""

# Get access token
echo "Step 1: Getting access token..."
ACCESS_TOKEN=$(./get-access-token.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" 2>/dev/null | grep -A1 "Access Token:" | tail -1 | tr -d ' ')
echo "✅ Access token obtained"
echo ""

# Process each user
TOKENS_FILE="bot-zak-tokens.env"
echo "# ZAK Tokens for bots (generated on $(date))" > "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

BOT_NUM=1
while IFS= read -r USER_EMAIL || [ -n "$USER_EMAIL" ]; do
    # Skip empty lines and comments
    [[ -z "$USER_EMAIL" || "$USER_EMAIL" =~ ^# ]] && continue
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Processing Bot $BOT_NUM: $USER_EMAIL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Find profile picture
    PROFILE_PIC=""
    for ext in jpg jpeg png JPG JPEG PNG; do
        if [ -f "$PROFILE_PICS_DIR/bot$BOT_NUM.$ext" ]; then
            PROFILE_PIC="$PROFILE_PICS_DIR/bot$BOT_NUM.$ext"
            break
        fi
    done
    
    if [ -z "$PROFILE_PIC" ]; then
        echo "⚠️  No profile picture found for bot$BOT_NUM"
        echo "   Looking for: $PROFILE_PICS_DIR/bot$BOT_NUM.{jpg,jpeg,png}"
        echo "   Skipping upload for this bot"
    else
        echo "📸 Uploading profile picture: $PROFILE_PIC"
        UPLOAD_OUTPUT=$(./upload-profile-picture.sh "$USER_EMAIL" "$PROFILE_PIC" "$ACCESS_TOKEN" 2>&1)
        UPLOAD_EXIT=$?
        
        if [ $UPLOAD_EXIT -eq 0 ]; then
            echo "✅ Profile picture uploaded successfully"
        else
            echo "❌ Failed to upload profile picture:"
            echo "$UPLOAD_OUTPUT" | tail -3
        fi
    fi
    
    echo ""
    echo "🔑 Generating ZAK token..."
    ZAK_TOKEN=$(./get-zak-token.sh "$USER_EMAIL" "$ACCESS_TOKEN" 2>/dev/null | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
    
    if [ -z "$ZAK_TOKEN" ]; then
        echo "❌ Failed to get ZAK token for $USER_EMAIL"
        continue
    fi
    
    echo "✅ ZAK token generated"
    echo ""
    
    # Save to tokens file
    echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" >> "$TOKENS_FILE"
    echo "BOT${BOT_NUM}_EMAIL=$USER_EMAIL" >> "$TOKENS_FILE"
    echo "" >> "$TOKENS_FILE"
    
    BOT_NUM=$((BOT_NUM + 1))
done < "$USERS_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 ZAK tokens saved to: $TOKENS_FILE"
echo ""
echo "💡 To use in compose file, source the tokens:"
echo "   source bot-zak-tokens.env"
echo ""
echo "💡 Then use in compose:"
echo "   - \"--zak\""
echo "   - \"\${BOT1_ZAK_TOKEN}\""


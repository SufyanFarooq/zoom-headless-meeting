#!/bin/bash

# Script to update profile pictures for all bots
# Reads emails from users.txt and uploads corresponding profile pictures
# Usage: ./update-profile-pictures.sh <account_id> <client_id> <client_secret> [users_file] [pics_dir]

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> [users_file] [pics_dir]"
    echo ""
    echo "Example:"
    echo "  $0 kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    echo ""
    echo "Optional:"
    echo "  users_file: Path to users.txt (default: profile-pics/users.txt)"
    echo "  pics_dir: Directory with profile pictures (default: profile-pics)"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERS_FILE="${4:-profile-pics/users.txt}"
PICS_DIR="${5:-profile-pics}"

if [ ! -f "$USERS_FILE" ]; then
    echo "❌ Error: Users file not found: $USERS_FILE"
    exit 1
fi

if [ ! -d "$PICS_DIR" ]; then
    echo "❌ Error: Profile pictures directory not found: $PICS_DIR"
    exit 1
fi

echo "📸 Updating Profile Pictures for Bots"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get access token
echo "Step 1: Getting access token..."
ACCESS_TOKEN=$(./get-access-token.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" 2>/dev/null | grep -A1 "Access Token:" | tail -1 | tr -d ' ')
if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    exit 1
fi
echo "✅ Access token obtained"
echo ""

# Process each user
BOT_NUM=1
SUCCESS=0
FAILED=0

echo "Step 2: Uploading profile pictures..."
echo ""

while IFS= read -r USER_EMAIL || [ -n "$USER_EMAIL" ]; do
    # Skip empty lines and comments
    [[ -z "$USER_EMAIL" || "$USER_EMAIL" =~ ^# ]] && continue
    
    EMAIL=$(echo "$USER_EMAIL" | awk '{print $1}')  # Get email (first word)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bot $BOT_NUM: $EMAIL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Find profile picture
    PROFILE_PIC=""
    for ext in jpg jpeg png JPG JPEG PNG; do
        if [ -f "$PICS_DIR/bot$BOT_NUM.$ext" ]; then
            PROFILE_PIC="$PICS_DIR/bot$BOT_NUM.$ext"
            break
        fi
    done
    
    if [ -z "$PROFILE_PIC" ]; then
        echo "⚠️  No profile picture found for bot$BOT_NUM"
        echo "   Looking for: $PICS_DIR/bot$BOT_NUM.{jpg,jpeg,png}"
        echo "   Skipping..."
        FAILED=$((FAILED + 1))
    else
        echo "📸 Uploading: $PROFILE_PIC"
        UPLOAD_OUTPUT=$(./upload-profile-picture.sh "$EMAIL" "$PROFILE_PIC" "$ACCESS_TOKEN" 2>&1)
        UPLOAD_EXIT=$?
        
        if [ $UPLOAD_EXIT -eq 0 ]; then
            echo "✅ Profile picture uploaded successfully"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ Failed to upload profile picture:"
            echo "$UPLOAD_OUTPUT" | tail -3
            FAILED=$((FAILED + 1))
        fi
    fi
    
    echo ""
    BOT_NUM=$((BOT_NUM + 1))
done < "$USERS_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Profile Picture Update Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "   ✅ Successful: $SUCCESS"
echo "   ❌ Failed: $FAILED"
echo "   📁 Total processed: $((SUCCESS + FAILED))"
echo ""
echo "💡 Profile pictures will appear when bots join with ZAK tokens"


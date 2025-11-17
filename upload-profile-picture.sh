#!/bin/bash

# Script to upload profile picture to Zoom user account
# Usage: ./upload-profile-picture.sh <user_email> <image_path> <access_token>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <user_email> <image_path> <access_token>"
    echo ""
    echo "Example:"
    echo "  $0 bot1@example.com profile-pics/bot1.jpg YOUR_ACCESS_TOKEN"
    echo ""
    echo "Image requirements:"
    echo "  - Format: JPG or PNG"
    echo "  - Size: Max 2MB"
    echo "  - Recommended: 400x400px square"
    exit 1
fi

USER_EMAIL="$1"
IMAGE_PATH="$2"
ACCESS_TOKEN="$3"

# Check if image file exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo "❌ Error: Image file not found: $IMAGE_PATH"
    exit 1
fi

# Check file size (max 2MB)
FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null)
MAX_SIZE=$((2 * 1024 * 1024))  # 2MB in bytes

if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
    echo "❌ Error: Image file too large (max 2MB)"
    echo "Current size: $((FILE_SIZE / 1024))KB"
    exit 1
fi

echo "📸 Uploading profile picture for user: $USER_EMAIL"
echo "📁 Image: $IMAGE_PATH"
echo ""

# First, get user ID from email
echo "📧 Looking up user ID..."
USER_RESPONSE=$(curl -s -X GET "https://api.zoom.us/v2/users/$USER_EMAIL" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
    echo "❌ Error: Could not find user with email: $USER_EMAIL"
    echo "Response: $USER_RESPONSE"
    exit 1
fi

echo "✅ Found user ID: $USER_ID"
echo ""

# Upload profile picture
echo "⬆️  Uploading profile picture..."
UPLOAD_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "https://api.zoom.us/v2/users/$USER_ID/picture" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "pic_file=@$IMAGE_PATH")

# Extract HTTP status code
HTTP_STATUS=$(echo "$UPLOAD_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | grep -v "HTTP_STATUS")

# Check if upload was successful
if [ "$HTTP_STATUS" != "201" ] && [ "$HTTP_STATUS" != "200" ]; then
    echo "❌ Error uploading profile picture (HTTP $HTTP_STATUS):"
    echo "$RESPONSE_BODY"
    
    # Check for permission errors
    if echo "$RESPONSE_BODY" | grep -qi "permission\|unauthorized\|forbidden\|insufficient"; then
        echo ""
        echo "⚠️  PERMISSION ERROR DETECTED!"
        echo "💡 Enable these scopes in Zoom app:"
        echo "   - user:read:admin"
        echo "   - user:write:admin"
        echo "   - user:write"
        echo ""
        echo "📝 See SETUP_APP_PERMISSIONS.md for details"
    fi
    exit 1
fi

echo "✅ Profile picture uploaded successfully!"
echo ""
echo "💡 Profile picture will appear when user joins meetings"
echo "💡 Use ZAK token from this account to show profile picture in bots"


#!/bin/bash

# Script to upload a single profile picture
# Usage: ./upload-single-profile-picture.sh <email> <image_path> <account_id> <client_id> <client_secret>

set -e

if [ $# -lt 5 ]; then
    echo "Usage: $0 <email> <image_path> <account_id> <client_id> <client_secret>"
    echo ""
    echo "Example:"
    echo "  $0 bot1@example.com profile-pics/bot1.jpg kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    exit 1
fi

USER_EMAIL="$1"
IMAGE_PATH="$2"
ACCOUNT_ID="$3"
CLIENT_ID="$4"
CLIENT_SECRET="$5"

echo "📸 Uploading profile picture for: $USER_EMAIL"
echo ""

# Get access token
ACCESS_TOKEN=$(./get-access-token.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" 2>/dev/null | grep -A1 "Access Token:" | tail -1 | tr -d ' ')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    exit 1
fi

# Upload profile picture
./upload-profile-picture.sh "$USER_EMAIL" "$IMAGE_PATH" "$ACCESS_TOKEN"


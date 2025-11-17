#!/bin/bash

# Script to get ZAK token for a Zoom user
# Usage: ./get-zak-token.sh <user_email> <access_token>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <user_email> <access_token>"
    echo ""
    echo "Example:"
    echo "  $0 bot1@example.com YOUR_ACCESS_TOKEN"
    echo ""
    echo "To get access token, use get-access-token.sh first"
    exit 1
fi

USER_EMAIL="$1"
ACCESS_TOKEN="$2"

echo "🔑 Getting ZAK token for user: $USER_EMAIL"
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

# Get ZAK token
echo "🔐 Generating ZAK token..."
# Use correct endpoint: GET /v2/users/{userId}/token?type=zak
# Reference: https://developers.zoom.us/docs/api/users/#tag/users/get/users/me/zak
ZAK_RESPONSE=$(curl -s -X GET "https://api.zoom.us/v2/users/$USER_ID/token?type=zak" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# Check for errors
if echo "$ZAK_RESPONSE" | grep -q "error\|code"; then
    ERROR_CODE=$(echo "$ZAK_RESPONSE" | grep -o '"code":[0-9]*' | cut -d: -f2)
    ERROR_MSG=$(echo "$ZAK_RESPONSE" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    if [ ! -z "$ERROR_CODE" ]; then
        echo "❌ API Error (Code: $ERROR_CODE): $ERROR_MSG"
        echo "Response: $ZAK_RESPONSE"
        exit 1
    fi
fi

ZAK_TOKEN=$(echo "$ZAK_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ZAK_TOKEN" ]; then
    echo "❌ Error: Could not get ZAK token"
    echo "Response: $ZAK_RESPONSE"
    exit 1
fi

echo "✅ ZAK Token generated successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ZAK Token:"
echo "$ZAK_TOKEN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Save this token securely!"
echo "💡 Token expires in 2 hours (7200 seconds)"
echo ""
echo "📝 Add to compose file:"
echo "  - \"--zak\""
echo "  - \"$ZAK_TOKEN\""


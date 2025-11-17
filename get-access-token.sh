#!/bin/bash

# Script to get Zoom API access token (Server-to-Server OAuth)
# Usage: ./get-access-token.sh <account_id> <client_id> <client_secret>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret>"
    echo ""
    echo "Get these from: https://marketplace.zoom.us/develop/create"
    echo ""
    echo "Example:"
    echo "  $0 YOUR_ACCOUNT_ID YOUR_CLIENT_ID YOUR_CLIENT_SECRET"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"

echo "🔑 Getting Zoom API access token..."
echo ""

# Create base64 encoded credentials
CREDENTIALS=$(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)

# Get access token
RESPONSE=$(curl -s -X POST "https://zoom.us/oauth/token?grant_type=account_credentials&account_id=$ACCOUNT_ID" \
  -H "Authorization: Basic $CREDENTIALS")

ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Error: Could not get access token"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Access token generated successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Access Token:"
echo "$ACCESS_TOKEN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 This token expires in 1 hour"
echo "💡 Use this token with get-zak-token.sh"
echo ""
echo "📝 Example:"
echo "  ./get-zak-token.sh bot1@example.com \"$ACCESS_TOKEN\""


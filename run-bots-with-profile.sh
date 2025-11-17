#!/bin/bash

# Quick script to generate ZAK tokens and run bots with profile pictures
# Usage: ./run-bots-with-profile.sh <account_id> <client_id> <client_secret>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret>"
    echo ""
    echo "Example:"
    echo "  $0 kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"

echo "🚀 Setting up bots with profile pictures..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Generate ZAK tokens
echo "Step 1: Generating fresh ZAK tokens..."
echo ""
if ./auto-setup-all-bots.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET"; then
    echo ""
    echo "✅ ZAK tokens generated successfully!"
    echo ""
else
    echo ""
    echo "❌ Failed to generate ZAK tokens"
    exit 1
fi

# Step 2: Run bots
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Starting bots..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Press Ctrl+C to stop all bots"
echo ""

docker compose -f compose-50-bots.yaml up --build


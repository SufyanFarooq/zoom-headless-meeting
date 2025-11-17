#!/bin/bash

# Complete automated setup:
# 1. Read emails from users.txt
# 2. Generate ZAK tokens
# 3. Update compose file automatically

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
USERS_FILE="profile-pics/users.txt"

echo "🚀 Automated Bot Setup - Complete Process"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Generate ZAK tokens
echo "Step 1: Generating ZAK tokens from $USERS_FILE..."
echo ""

./auto-setup-bots.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" "$USERS_FILE"

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate ZAK tokens"
    exit 1
fi

echo ""
echo "Step 2: Updating compose file..."
echo ""

# Step 2: Update compose file
./update-compose-with-zak.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Complete Setup Finished!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 All bots in users.txt now have:"
echo "   ✅ ZAK tokens generated"
echo "   ✅ Compose file updated"
echo ""
echo "💡 Test bots:"
echo "   docker compose -f compose-50-bots.yaml up --build bot-1 bot-2"


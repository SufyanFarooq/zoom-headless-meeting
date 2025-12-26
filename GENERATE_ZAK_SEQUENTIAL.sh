#!/bin/bash

# Sequential ZAK token generation (works on all bash versions)
# Usage: ./GENERATE_ZAK_SEQUENTIAL.sh

ACCOUNT_ID="kOjrXedBRwGlbGiCyzQOyQ"
CLIENT_ID="9bk9CyXgSgqggGe5InpVMA"
CLIENT_SECRET="OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
USERS_FILE="profile-pics/users.txt"

echo "🚀 Sequential ZAK Token Generation"
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

# Count emails
EMAIL_COUNT=$(grep -c "@" "$USERS_FILE" 2>/dev/null || echo "0")
echo "Found $EMAIL_COUNT emails in $USERS_FILE"
echo ""

# Generate tokens sequentially
TOKENS_FILE="bot-zak-tokens.env"
echo "# ZAK Tokens for bots (auto-generated on $(date))" > "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

BOT_NUM=1
SUCCESS=0
FAILED=0

while IFS= read -r LINE || [ -n "$LINE" ]; do
    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue
    
    if [[ "$LINE" =~ @ ]]; then
        EMAIL=$(echo "$LINE" | awk '{print $1}')
        
        echo "[$BOT_NUM/$EMAIL_COUNT] Generating ZAK token for: $EMAIL"
        
        ZAK_OUTPUT=$(./get-zak-token.sh "$EMAIL" "$ACCESS_TOKEN" 2>&1)
        ZAK_TOKEN=$(echo "$ZAK_OUTPUT" | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
        
        if [ -z "$ZAK_TOKEN" ] || [ ${#ZAK_TOKEN} -lt 50 ]; then
            echo "❌ Failed for $EMAIL"
            echo "$ZAK_OUTPUT" | tail -3
            FAILED=$((FAILED + 1))
        else
            echo "✅ Token generated"
            echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" >> "$TOKENS_FILE"
            echo "BOT${BOT_NUM}_EMAIL=$EMAIL" >> "$TOKENS_FILE"
            echo "" >> "$TOKENS_FILE"
            SUCCESS=$((SUCCESS + 1))
        fi
        
        BOT_NUM=$((BOT_NUM + 1))
    fi
done < "$USERS_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Generation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Success: $SUCCESS"
echo "   Failed: $FAILED"
echo "   Total: $EMAIL_COUNT"
echo "   Tokens file: $TOKENS_FILE"
echo ""


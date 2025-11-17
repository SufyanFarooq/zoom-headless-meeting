#!/bin/bash

# Script to create Zoom user accounts via API
# This creates users under your main Zoom account
# Usage: ./create-zoom-users.sh <account_id> <client_id> <client_secret> <users_file>

set -e

if [ $# -lt 4 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> <users_file>"
    echo ""
    echo "users_file format (one per line):"
    echo "  bot1@example.com Bot1 User"
    echo "  bot2@example.com Bot2 User"
    echo "  bot3@example.com Bot3 User"
    echo ""
    echo "Example:"
    echo "  $0 YOUR_ACCOUNT_ID YOUR_CLIENT_ID YOUR_CLIENT_SECRET users-list.txt"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERS_FILE="$4"

# Try to find the file if exact name not found
if [ ! -f "$USERS_FILE" ]; then
    # Try common variations
    if [ -f "user-list.txt" ]; then
        USERS_FILE="user-list.txt"
        echo "ℹ️  Using user-list.txt instead"
    elif [ -f "users.txt" ]; then
        USERS_FILE="users.txt"
        echo "ℹ️  Using users.txt instead"
    else
        echo "❌ Error: Users file not found: $USERS_FILE"
        echo "💡 Tried: $USERS_FILE, user-list.txt, users.txt"
        exit 1
    fi
fi

echo "🔑 Getting access token..."
CREDENTIALS=$(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)
ACCESS_TOKEN_RESPONSE=$(curl -s -X POST "https://zoom.us/oauth/token?grant_type=account_credentials&account_id=$ACCOUNT_ID" \
  -H "Authorization: Basic $CREDENTIALS")

ACCESS_TOKEN=$(echo "$ACCESS_TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Error: Could not get access token"
    echo "Response: $ACCESS_TOKEN_RESPONSE"
    exit 1
fi

echo "✅ Access token obtained"
echo ""

# Create users
echo "👥 Creating Zoom user accounts..."
echo ""

CREATED_FILE="created-users.txt"
echo "# Created Zoom users on $(date)" > "$CREATED_FILE"
echo "" >> "$CREATED_FILE"

while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Skip empty lines and comments
    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue
    
    # Parse email and name
    EMAIL=$(echo "$LINE" | awk '{print $1}')
    NAME=$(echo "$LINE" | awk '{$1=""; print $0}' | xargs)
    
    if [ -z "$NAME" ]; then
        NAME="$EMAIL"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating: $EMAIL ($NAME)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Create user
    CREATE_RESPONSE=$(curl -s -X POST "https://api.zoom.us/v2/users" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"action\": \"create\",
        \"user_info\": {
          \"email\": \"$EMAIL\",
          \"type\": 1,
          \"first_name\": \"$NAME\",
          \"last_name\": \"Bot\"
        }
      }")
    
    # Check if user was created or already exists
    if echo "$CREATE_RESPONSE" | grep -q "already exists\|already in use"; then
        echo "⚠️  User already exists: $EMAIL"
        echo "$EMAIL" >> "$CREATED_FILE"
    elif echo "$CREATE_RESPONSE" | grep -q "id"; then
        USER_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
        echo "✅ User created: $EMAIL (ID: $USER_ID)"
        echo "$EMAIL" >> "$CREATED_FILE"
    else
        echo "❌ Error creating user: $EMAIL"
        echo "Response: $CREATE_RESPONSE"
        continue
    fi
    
    echo ""
done < "$USERS_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ User creation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Created users saved to: $CREATED_FILE"
echo ""
echo "💡 Next steps:"
echo "   1. Update profile-pics/users.txt with these emails"
echo "   2. Run: ./setup-bot-profiles.sh $ACCOUNT_ID $CLIENT_ID $CLIENT_SECRET ./profile-pics"


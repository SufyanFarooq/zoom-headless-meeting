#!/bin/bash

# Automated script to:
# 1. Read emails from users.txt
# 2. Generate ZAK tokens for each
# 3. Update compose file automatically

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> [users_file]"
    echo ""
    echo "Example:"
    echo "  $0 kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    echo ""
    echo "Optional: users_file (default: profile-pics/users.txt)"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERS_FILE="${4:-profile-pics/users.txt}"

if [ ! -f "$USERS_FILE" ]; then
    echo "❌ Error: Users file not found: $USERS_FILE"
    exit 1
fi

echo "🚀 Automated Bot Setup with ZAK Tokens"
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

# Generate ZAK tokens for all users
echo "Step 2: Generating ZAK tokens..."
echo ""

TOKENS_FILE="bot-zak-tokens.env"
echo "# ZAK Tokens for bots (auto-generated on $(date))" > "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

BOT_NUM=1
# Use associative arrays to track bot_num -> token/email mapping
# This prevents array misalignment when token generation fails
declare -A BOT_TOKENS=()
declare -A BOT_EMAILS=()

while IFS= read -r USER_EMAIL || [ -n "$USER_EMAIL" ]; do
    # Skip empty lines and comments
    [[ -z "$USER_EMAIL" || "$USER_EMAIL" =~ ^# ]] && continue
    
    EMAIL=$(echo "$USER_EMAIL" | awk '{print $1}')  # Get email (first word)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bot $BOT_NUM: $EMAIL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Generate ZAK token
    ZAK_OUTPUT=$(./get-zak-token.sh "$EMAIL" "$ACCESS_TOKEN" 2>&1)
    ZAK_TOKEN=$(echo "$ZAK_OUTPUT" | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
    
    if [ -z "$ZAK_TOKEN" ] || [ ${#ZAK_TOKEN} -lt 50 ]; then
        echo "❌ Failed to generate ZAK token for $EMAIL"
        echo "$ZAK_OUTPUT" | tail -3
        echo "⚠️  Skipping bot-$BOT_NUM (will not be added to compose file)"
        echo ""
        BOT_NUM=$((BOT_NUM + 1))
        continue
    fi
    
    # Only add to arrays if token generation succeeded
    BOT_TOKENS[$BOT_NUM]="$ZAK_TOKEN"
    BOT_EMAILS[$BOT_NUM]="$EMAIL"
    
    echo "✅ ZAK token generated"
    echo ""
    
    # Save to tokens file
    echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" >> "$TOKENS_FILE"
    echo "BOT${BOT_NUM}_EMAIL=$EMAIL" >> "$TOKENS_FILE"
    echo "" >> "$TOKENS_FILE"
    
    BOT_NUM=$((BOT_NUM + 1))
done < "$USERS_FILE"

TOTAL_BOTS=$((BOT_NUM - 1))
SUCCESSFUL_BOTS=${#BOT_TOKENS[@]}

if [ $SUCCESSFUL_BOTS -eq 0 ]; then
    echo "❌ No ZAK tokens generated successfully"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Generated ZAK tokens for $SUCCESSFUL_BOTS bots (out of $TOTAL_BOTS total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Update compose file
echo "Step 3: Updating compose file..."
COMPOSE_FILE="compose-50-bots.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    exit 1
fi

# Create backup
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created: ${COMPOSE_FILE}.backup.*"

# Update each bot in compose file
# Iterate over bots that successfully got tokens
for BOT_NUM in $(printf '%s\n' "${!BOT_TOKENS[@]}" | sort -n); do
    ZAK_TOKEN="${BOT_TOKENS[$BOT_NUM]}"
    EMAIL="${BOT_EMAILS[$BOT_NUM]}"
    
    if [ -z "$ZAK_TOKEN" ]; then
        echo "⚠️  Skipping bot-${BOT_NUM} (no ZAK token)"
        continue
    fi
    
    # Check if ZAK already exists in compose file
    if grep -A 15 "bot-${BOT_NUM}:" "$COMPOSE_FILE" | grep -q "\"--zak\""; then
        # Update existing ZAK token
        echo "🔄 Updating ZAK token for bot-${BOT_NUM}..."
        
        # Find the line with --zak and replace the token on the next line
        # Pattern: --zak followed by token on next line
        # Use sed to replace the token value while keeping --zak flag
        sed -i.bak "/bot-${BOT_NUM}:/,/stop_grace_period:/ {
            /--zak/,+1 {
                /--zak/! {
                    s|^\\(      - \\)\".*\"|\\1\"${ZAK_TOKEN}\"|
                }
            }
        }" "$COMPOSE_FILE" 2>/dev/null || {
            # Fallback: Use Python script if sed fails
            echo "   Using Python script for update..."
            python3 update-compose-zak.py 2>/dev/null || {
                echo "⚠️  Could not auto-update bot-${BOT_NUM} in compose file"
                echo "   Manual update needed:"
                echo "   Bot-${BOT_NUM}: Update --zak token to \"${ZAK_TOKEN}\""
            }
        }
    else
        # Add new ZAK token
        echo "➕ Adding ZAK token for bot-${BOT_NUM}..."
        # Use sed to insert after --config config.toml
        sed -i.bak "/bot-${BOT_NUM}:/,/stop_grace_period:/ {
            /--config/,/config.toml/ {
                /config.toml/a\\
      - \"--zak\"\\
      - \"${ZAK_TOKEN}\"
            }
        }" "$COMPOSE_FILE" 2>/dev/null || {
            echo "⚠️  Could not auto-update bot-${BOT_NUM} in compose file"
            echo "   Manual update needed:"
            echo "   Bot-${BOT_NUM}: Add --zak \"${ZAK_TOKEN}\" after --config config.toml"
        }
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Summary:"
echo "   - ZAK tokens generated: $SUCCESSFUL_BOTS (out of $TOTAL_BOTS bots)"
echo "   - Tokens saved to: $TOKENS_FILE"
echo "   - Compose file: $COMPOSE_FILE (backup created)"
echo ""
echo "💡 Next: Review compose file and test:"
echo "   docker compose -f $COMPOSE_FILE up --build bot-1"


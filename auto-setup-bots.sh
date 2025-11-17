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
declare -a EMAILS=()
declare -a ZAK_TOKENS=()

while IFS= read -r USER_EMAIL || [ -n "$USER_EMAIL" ]; do
    # Skip empty lines and comments
    [[ -z "$USER_EMAIL" || "$USER_EMAIL" =~ ^# ]] && continue
    
    EMAIL=$(echo "$USER_EMAIL" | awk '{print $1}')  # Get email (first word)
    EMAILS+=("$EMAIL")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bot $BOT_NUM: $EMAIL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Generate ZAK token
    ZAK_OUTPUT=$(./get-zak-token.sh "$EMAIL" "$ACCESS_TOKEN" 2>&1)
    ZAK_TOKEN=$(echo "$ZAK_OUTPUT" | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
    
    if [ -z "$ZAK_TOKEN" ] || [ ${#ZAK_TOKEN} -lt 50 ]; then
        echo "❌ Failed to generate ZAK token for $EMAIL"
        echo "$ZAK_OUTPUT" | tail -3
        continue
    fi
    
    ZAK_TOKENS+=("$ZAK_TOKEN")
    
    echo "✅ ZAK token generated"
    echo ""
    
    # Save to tokens file
    echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" >> "$TOKENS_FILE"
    echo "BOT${BOT_NUM}_EMAIL=$EMAIL" >> "$TOKENS_FILE"
    echo "" >> "$TOKENS_FILE"
    
    BOT_NUM=$((BOT_NUM + 1))
done < "$USERS_FILE"

TOTAL_BOTS=$((BOT_NUM - 1))

if [ $TOTAL_BOTS -eq 0 ]; then
    echo "❌ No valid users found in $USERS_FILE"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Generated ZAK tokens for $TOTAL_BOTS bots"
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
for i in $(seq 1 $TOTAL_BOTS); do
    BOT_INDEX=$((i - 1))
    EMAIL="${EMAILS[$BOT_INDEX]}"
    ZAK_TOKEN="${ZAK_TOKENS[$BOT_INDEX]}"
    
    if [ -z "$ZAK_TOKEN" ]; then
        echo "⚠️  Skipping bot-$i (no ZAK token)"
        continue
    fi
    
    # Find bot section and add/update ZAK token
    # Look for pattern: bot-${i}: ... --display-name ... --config ... config.toml
    # Add --zak and token after --config config.toml
    
    # Use sed to add ZAK token after --config config.toml
    # First, check if ZAK already exists
    if grep -A 10 "bot-${i}:" "$COMPOSE_FILE" | grep -q "\"--zak\""; then
        # Update existing ZAK token
        echo "🔄 Updating ZAK token for bot-${i}..."
        # This is complex with sed, so we'll use a Python/perl script or manual instruction
        # For now, we'll create a helper script
    else
        # Add new ZAK token
        echo "➕ Adding ZAK token for bot-${i}..."
        # Use sed to insert after --config config.toml
        sed -i.bak "/bot-${i}:/,/stop_grace_period:/ {
            /--config/,/config.toml/ {
                /config.toml/a\\
      - \"--zak\"\\
      - \"${ZAK_TOKEN}\"
            }
        }" "$COMPOSE_FILE" 2>/dev/null || {
            echo "⚠️  Could not auto-update bot-${i} in compose file"
            echo "   Manual update needed:"
            echo "   Bot-${i}: Add --zak \"${ZAK_TOKEN}\" after --config config.toml"
        }
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Summary:"
echo "   - ZAK tokens generated: $TOTAL_BOTS"
echo "   - Tokens saved to: $TOKENS_FILE"
echo "   - Compose file: $COMPOSE_FILE (backup created)"
echo ""
echo "💡 Next: Review compose file and test:"
echo "   docker compose -f $COMPOSE_FILE up --build bot-1"


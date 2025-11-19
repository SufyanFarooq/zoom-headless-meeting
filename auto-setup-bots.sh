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
# Use regular arrays (bash 3.2 compatible)
# Track successful bots separately to prevent misalignment
BOT_TOKENS=()
BOT_EMAILS=()
BOT_NUMS=()  # Track which bot numbers succeeded

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
    BOT_TOKENS+=("$ZAK_TOKEN")
    BOT_EMAILS+=("$EMAIL")
    BOT_NUMS+=("$BOT_NUM")
    
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
i=0
while [ $i -lt $SUCCESSFUL_BOTS ]; do
    BOT_NUM="${BOT_NUMS[$i]}"
    ZAK_TOKEN="${BOT_TOKENS[$i]}"
    EMAIL="${BOT_EMAILS[$i]}"
    
    if [ -z "$ZAK_TOKEN" ]; then
        echo "⚠️  Skipping bot-${BOT_NUM} (no ZAK token)"
        i=$((i + 1))
        continue
    fi
    
    # Check if ZAK already exists in compose file
    if grep -A 15 "bot-${BOT_NUM}:" "$COMPOSE_FILE" | grep -q "\"--zak\""; then
        # Update existing ZAK token (remove all duplicates first, then add one)
        echo "🔄 Updating ZAK token for bot-${BOT_NUM}..."
        
        # First, use Python script to remove all duplicates and update
        COMPOSE_FILE="$COMPOSE_FILE" BOT_NUM=$BOT_NUM ZAK_TOKEN="$ZAK_TOKEN" python3 << 'PYTHON_UPDATE_SCRIPT'
import yaml
import sys
import os

COMPOSE_FILE = os.environ.get('COMPOSE_FILE', 'compose-50-bots.yaml')
BOT_NUM = int(os.environ.get('BOT_NUM', '0'))
ZAK_TOKEN = os.environ.get('ZAK_TOKEN', '')

if not ZAK_TOKEN or BOT_NUM == 0:
    sys.exit(1)

try:
    with open(COMPOSE_FILE, 'r') as f:
        compose_data = yaml.safe_load(f)
    
    if not compose_data or 'services' not in compose_data:
        sys.exit(1)
    
    service_name = f"bot-{BOT_NUM}"
    if service_name not in compose_data['services']:
        sys.exit(1)
    
    command_list = compose_data['services'][service_name].get('command', [])
    
    # Remove ALL existing --zak entries and their tokens
    new_command = []
    i = 0
    while i < len(command_list):
        if command_list[i] == "--zak":
            # Skip --zak and the token after it
            i += 2
            continue
        new_command.append(command_list[i])
        i += 1
    
    # Find position to insert --zak (after --config config.toml)
    insert_idx = -1
    for i, item in enumerate(new_command):
        if "config.toml" in str(item):
            insert_idx = i + 1
            break
    
    if insert_idx != -1:
        new_command.insert(insert_idx, ZAK_TOKEN)
        new_command.insert(insert_idx, "--zak")
        compose_data['services'][service_name]['command'] = new_command
        
        with open(COMPOSE_FILE, 'w') as f:
            yaml.dump(compose_data, f, sort_keys=False, indent=2, default_flow_style=False)
        
        print("   ✅ Updated ZAK token (removed duplicates)")
    else:
        sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_UPDATE_SCRIPT
        
        if [ $? -ne 0 ]; then
            # Fallback: Use update-compose-zak.py script
            echo "   Using update-compose-zak.py script..."
            python3 update-compose-zak.py 2>/dev/null || {
                echo "⚠️  Could not auto-update bot-${BOT_NUM} in compose file"
                echo "   Manual update needed:"
                echo "   Bot-${BOT_NUM}: Update --zak token to \"${ZAK_TOKEN}\""
            }
        fi
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
    
    i=$((i + 1))
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


#!/bin/bash

# Parallel ZAK token generation script
# Usage: ./generate-zak-tokens-parallel.sh <account_id> <client_id> <client_secret> <users_file> [parallel_jobs]
# 
# This script generates ZAK tokens in parallel for faster processing
# Default: 10 parallel jobs (can be adjusted based on API rate limits)

set -e

if [ $# -lt 4 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> <users_file> [parallel_jobs]"
    echo ""
    echo "Example:"
    echo "  $0 kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS profile-pics/users.txt 20"
    echo ""
    echo "Optional: parallel_jobs (default: 10, max recommended: 20)"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERS_FILE="$4"
PARALLEL_JOBS="${5:-10}"

# Validate parallel jobs (max 50 - Zoom API rate limits vary; scale for 150+ bot requests)
if [ "$PARALLEL_JOBS" -gt 50 ]; then
    echo "⚠️  Warning: Parallel jobs ($PARALLEL_JOBS) exceeds max (50). Using 50."
    PARALLEL_JOBS=50
fi

if [ ! -f "$USERS_FILE" ]; then
    echo "❌ Error: Users file not found: $USERS_FILE"
    exit 1
fi

echo "🚀 Parallel ZAK Token Generation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Parallel jobs: $PARALLEL_JOBS"
echo "   Users file: $USERS_FILE"
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
EMAIL_COUNT=$(grep -c "@" "$USERS_FILE" || echo "0")
if [ "$EMAIL_COUNT" -eq 0 ]; then
    echo "⚠️  No emails found in $USERS_FILE"
    exit 0
fi

echo "Step 2: Generating ZAK tokens in parallel ($PARALLEL_JOBS jobs)..."
echo "   Found $EMAIL_COUNT emails"
echo ""

TOKENS_FILE="bot-zak-tokens.env"
echo "# ZAK Tokens for bots (auto-generated on $(date))" > "$TOKENS_FILE"
echo "# Generated with $PARALLEL_JOBS parallel jobs" >> "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

# Create temporary directory for parallel processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Prepare email list with bot numbers
BOT_NUM=1
EMAIL_LIST_FILE="$TEMP_DIR/email_list.txt"
while IFS= read -r LINE || [ -n "$LINE" ]; do
    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue
    
    if [[ "$LINE" =~ @ ]]; then
        EMAIL=$(echo "$LINE" | awk '{print $1}')
        echo "$BOT_NUM|$EMAIL" >> "$EMAIL_LIST_FILE"
        BOT_NUM=$((BOT_NUM + 1))
    fi
done < "$USERS_FILE"

TOTAL_BOTS=$((BOT_NUM - 1))

# Process emails in parallel using background jobs
echo "   Processing $EMAIL_COUNT emails with $PARALLEL_JOBS parallel jobs..."
echo ""

# Function to generate token for a single email
generate_single_token() {
    local BOT_NUM="$1"
    local EMAIL="$2"
    local OUTPUT_FILE="$TEMP_DIR/bot_${BOT_NUM}.result"
    
    # Generate ZAK token (suppress most output)
    ZAK_OUTPUT=$(./get-zak-token.sh "$EMAIL" "$ACCESS_TOKEN" 2>&1)
    ZAK_TOKEN=$(echo "$ZAK_OUTPUT" | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
    
    if [ -z "$ZAK_TOKEN" ] || [ ${#ZAK_TOKEN} -lt 50 ]; then
        echo "FAIL|$BOT_NUM|$EMAIL" > "$OUTPUT_FILE"
        return 1
    fi
    
    # Save token info
    echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" > "$OUTPUT_FILE"
    echo "BOT${BOT_NUM}_EMAIL=$EMAIL" >> "$OUTPUT_FILE"
    echo "SUCCESS|$BOT_NUM|$EMAIL" >> "$OUTPUT_FILE"
    return 0
}

export -f generate_single_token
export ACCESS_TOKEN TEMP_DIR

# Process emails in batches to control parallelism
ACTIVE_JOBS=0
SUCCESS_COUNT=0
FAIL_COUNT=0

while IFS='|' read -r BOT_NUM EMAIL; do
    # Wait if we've reached max parallel jobs
    while [ $ACTIVE_JOBS -ge $PARALLEL_JOBS ]; do
        wait -n  # Wait for any job to finish
        ACTIVE_JOBS=$((ACTIVE_JOBS - 1))
    done
    
    # Start background job
    (generate_single_token "$BOT_NUM" "$EMAIL") &
    ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
done < "$EMAIL_LIST_FILE"

# Wait for all remaining jobs
while [ $ACTIVE_JOBS -gt 0 ]; do
    wait -n
    ACTIVE_JOBS=$((ACTIVE_JOBS - 1))
done

# Collect results
while IFS='|' read -r BOT_NUM EMAIL; do
    RESULT_FILE="$TEMP_DIR/bot_${BOT_NUM}.result"
    
    if [ -f "$RESULT_FILE" ]; then
        STATUS=$(tail -1 "$RESULT_FILE" 2>/dev/null | cut -d'|' -f1)
        
        if [ "$STATUS" = "SUCCESS" ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            echo "✅ [$SUCCESS_COUNT/$EMAIL_COUNT] Bot $BOT_NUM: $EMAIL"
            
            # Append token to main file
            grep "^BOT${BOT_NUM}_" "$RESULT_FILE" | head -2 >> "$TOKENS_FILE" 2>/dev/null || true
            echo "" >> "$TOKENS_FILE"
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "❌ [$FAIL_COUNT failed] Bot $BOT_NUM: $EMAIL"
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "❌ [$FAIL_COUNT failed] Bot $BOT_NUM: $EMAIL (no result file)"
    fi
done < "$EMAIL_LIST_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Parallel generation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Success: $SUCCESS_COUNT"
echo "   Failed: $FAIL_COUNT"
echo "   Total: $EMAIL_COUNT"
echo "   Tokens file: $TOKENS_FILE"
echo ""

if [ $SUCCESS_COUNT -eq 0 ]; then
    echo "❌ No ZAK tokens generated successfully"
    exit 1
fi

echo "💡 Next step: Update compose file with tokens"
echo "   python3 update-compose-zak.py"

#!/bin/bash

# Setup flexible bots with ZAK token generation
# Usage: ./setup-flexible-bots.sh <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret> [users_file] [meeting_type]
# 
# meeting_type: "Normal Member" (default) or "Profile Pic Member"
# If meeting_type is "Profile Pic Member", ZAK tokens will be generated for bots with emails
# name_type: "Indian" (default) or "International" - determines which names file to use

set -e

VIDEO_COUNT=${1:-0}
AUDIO_COUNT=${2:-0}
JOIN_URL=${3:-""}
ACCOUNT_ID=${4:-""}
CLIENT_ID=${5:-""}
CLIENT_SECRET=${6:-""}
USERS_FILE=${7:-"profile-pics/users.txt"}
MEETING_TYPE_ARG=${8:-""}

if [ -z "$JOIN_URL" ] || [ -z "$ACCOUNT_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ Error: Missing required arguments"
    echo ""
    echo "Usage:"
    echo "  ./setup-flexible-bots.sh <video_count> <audio_count> <join_url> <account_id> <client_id> <client_secret> [users_file] [meeting_type]"
    echo ""
    echo "Example (Normal Member - no ZAK tokens):"
    echo "  ./setup-flexible-bots.sh 6 4 'https://zoom.us/j/xxx' kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    echo ""
    echo "Example (Profile Pic Member - with ZAK tokens):"
    echo "  ./setup-flexible-bots.sh 6 4 'https://zoom.us/j/xxx' kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS profile-pics/users.txt 'Profile Pic Member'"
    echo ""
    echo "This will create:"
    echo "  - 6 video-only bots"
    echo "  - 4 audio-only bots"
    echo ""
    echo "Meeting Types:"
    echo "  - 'Normal Member' (default): Bots join as guests"
    echo "  - 'Profile Pic Member': Bots with emails join with profiles (ZAK tokens)"
    exit 1
fi

TOTAL_BOTS=$((VIDEO_COUNT + AUDIO_COUNT))

if [ $TOTAL_BOTS -eq 0 ]; then
    echo "❌ Error: At least one bot type must be specified"
    exit 1
fi

echo "🚀 Setting up flexible bots..."
echo "   - Video-only: $VIDEO_COUNT"
echo "   - Audio-only: $AUDIO_COUNT"
echo "   - Total: $TOTAL_BOTS"

# Get name type from environment or default to Indian
NAME_TYPE="${NAME_TYPE:-Indian}"

echo ""
echo "📋 Name Type: $NAME_TYPE"
echo ""

# Step 1: Generate compose file
echo ""
echo "📝 Step 1: Generating compose file..."
./generate-flexible-bots.sh "$VIDEO_COUNT" "$AUDIO_COUNT" "$JOIN_URL" "Bot" "$USERS_FILE" "$NAME_TYPE"

# Step 2: Generate ZAK tokens for bots with emails (only for Profile Pic Member)
# MEETING_TYPE can come from:
# 1. Environment variable (set by bot-server API)
# 2. Command line argument (8th parameter)
# 3. Default to "Normal Member"
if [ -n "$MEETING_TYPE_ARG" ]; then
    MEETING_TYPE="$MEETING_TYPE_ARG"
elif [ -z "$MEETING_TYPE" ]; then
    MEETING_TYPE="Normal Member"
fi

echo ""
echo "📋 Meeting Type: $MEETING_TYPE"
echo ""

if [ "$MEETING_TYPE" = "Profile Pic Member" ]; then
    if [ -f "$USERS_FILE" ] && [ -s "$USERS_FILE" ]; then
        echo ""
        echo "🔑 Step 2: Generating ZAK tokens for Profile Pic Member..."
        
        # Count how many emails we have
        EMAIL_COUNT=$(wc -l < "$USERS_FILE" | tr -d ' ')
        
        if [ $EMAIL_COUNT -gt 0 ]; then
            # Determine how many bots need ZAK tokens
            # If we have more emails than bots, only use first TOTAL_BOTS emails
            # If we have fewer emails than bots, use all emails (rest will be guests)
            BOTS_NEEDING_ZAK=$((EMAIL_COUNT < TOTAL_BOTS ? EMAIL_COUNT : TOTAL_BOTS))
            
            echo "   Found $EMAIL_COUNT emails in $USERS_FILE"
            echo "   Total bots: $TOTAL_BOTS"
            echo "   Generating ZAK tokens for first $BOTS_NEEDING_ZAK bots..."
            
            # Create temporary users file with only the emails we need
            TEMP_USERS_FILE=$(mktemp)
            head -n $BOTS_NEEDING_ZAK "$USERS_FILE" > "$TEMP_USERS_FILE"
            
            # Call auto-setup-bots.sh with the ZAK token generation parameters
            # auto-setup-bots.sh expects: <account_id> <client_id> <client_secret> [users_file] [parallel_jobs]
            # Use parallel generation for 10+ bots (much faster!)
            echo "   Running auto-setup-bots.sh..."
            PARALLEL_JOBS=0
            if [ $BOTS_NEEDING_ZAK -ge 10 ]; then
                # Calculate optimal parallel jobs based on bot count
                # Formula: bots/8 (optimal batch size), min 5, max 10 (safe for API limits)
                # For 80 bots: 80/8 = 10 jobs (8 batches × 2s = 16s)
                # For 40 bots: 40/8 = 5 jobs (8 batches × 2s = 16s)
                # For 20 bots: 20/8 = 2.5 → 5 jobs (4 batches × 2s = 8s)
                OPTIMAL_JOBS=$((BOTS_NEEDING_ZAK / 8))
                if [ $OPTIMAL_JOBS -lt 5 ]; then
                    OPTIMAL_JOBS=5
                elif [ $OPTIMAL_JOBS -gt 10 ]; then
                    OPTIMAL_JOBS=10  # Cap at 10 for API safety
                fi
                PARALLEL_JOBS=$OPTIMAL_JOBS
                # Calculate estimated time (ceiling division: (n + d - 1) / d)
                BATCHES=$(( (BOTS_NEEDING_ZAK + PARALLEL_JOBS - 1) / PARALLEL_JOBS ))
                ESTIMATED_TIME=$((BATCHES * 2))
                SEQUENTIAL_TIME=$((BOTS_NEEDING_ZAK * 2))
                SPEEDUP=$((SEQUENTIAL_TIME / ESTIMATED_TIME))
                echo "   💡 Using parallel generation ($PARALLEL_JOBS jobs) for $BOTS_NEEDING_ZAK bots"
                echo "   ⚡ Estimated time: ~${ESTIMATED_TIME}s (vs ${SEQUENTIAL_TIME}s sequential) - ${SPEEDUP}x faster"
            else
                echo "   ℹ️  Using sequential generation for $BOTS_NEEDING_ZAK bots (< 10 bots)"
            fi
            if ./auto-setup-bots.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" "$TEMP_USERS_FILE" "$PARALLEL_JOBS"; then
                echo "   ✅ ZAK tokens generated successfully for $BOTS_NEEDING_ZAK bots"
                if [ $EMAIL_COUNT -gt $TOTAL_BOTS ]; then
                    echo "   ℹ️  Note: $((EMAIL_COUNT - TOTAL_BOTS)) extra emails not used (only $TOTAL_BOTS bots needed)"
                elif [ $EMAIL_COUNT -lt $TOTAL_BOTS ]; then
                    echo "   ℹ️  Note: $((TOTAL_BOTS - EMAIL_COUNT)) bots will join as guests (no emails available)"
                fi
            else
                echo "   ❌ Error: Failed to generate ZAK tokens"
                rm -f "$TEMP_USERS_FILE"
                exit 1
            fi
            
            # Clean up temp file
            rm -f "$TEMP_USERS_FILE"
            
            # Ensure ZAK tokens are added to compose file using update-compose-zak.py
            # This is a fallback in case auto-setup-bots.sh didn't properly update the file
            echo ""
            echo "🔄 Verifying ZAK tokens in compose file..."
            if [ -f "bot-zak-tokens.env" ]; then
                echo "   Found bot-zak-tokens.env file"
                echo "   Checking token count..."
                TOKEN_COUNT=$(grep -c "ZAK_TOKEN" bot-zak-tokens.env || echo "0")
                echo "   Found $TOKEN_COUNT ZAK tokens in file"
                
                echo "   Running update-compose-zak.py..."
                echo "   Current directory: $(pwd)"
                echo "   Checking files:"
                ls -la bot-zak-tokens.env compose-50-bots.yaml 2>&1 | head -3
                if python3 update-compose-zak.py; then
                    echo "   ✅ ZAK tokens added to compose file"
                    
                    # Verify ZAK tokens were added
                    ZAK_IN_COMPOSE=$(grep -c "\"--zak\"" compose-50-bots.yaml || echo "0")
                    echo "   Verified: $ZAK_IN_COMPOSE ZAK tokens found in compose file"
                    
                    if [ "$ZAK_IN_COMPOSE" -eq "0" ]; then
                        echo "   ⚠️  Warning: No ZAK tokens found in compose file after update"
                        echo "   Checking if tokens were added correctly..."
                        # Count bots that should have ZAK tokens
                        EXPECTED_ZAK=$((EMAIL_COUNT < TOTAL_BOTS ? EMAIL_COUNT : TOTAL_BOTS))
                        echo "   Expected: $EXPECTED_ZAK bots with ZAK tokens"
                        echo "   Found: $ZAK_IN_COMPOSE ZAK tokens in compose file"
                    fi
                else
                    echo "   ❌ Error: update-compose-zak.py failed"
                    exit 1
                fi
            else
                echo "   ❌ Error: bot-zak-tokens.env file not found after generation"
                exit 1
            fi
        else
            echo ""
            echo "⚠️  Step 2: No emails found in users file"
            echo "   Bots will join as guests without ZAK tokens"
        fi
    else
        echo ""
        echo "⚠️  Step 2: No users file found or file is empty"
        echo "   Bots will join as guests without ZAK tokens"
    fi
else
    echo ""
    echo "ℹ️  Step 2: Meeting type is '$MEETING_TYPE' - skipping ZAK token generation"
    echo "   Bots will join as guests"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start bots, run:"
echo "   docker compose -f compose-50-bots.yaml up -d"
echo ""
echo "To start specific bots:"
echo "   docker compose -f compose-50-bots.yaml up bot-1 bot-2 ..."


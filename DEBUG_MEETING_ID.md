# Debug Meeting ID Issue

## Problem
Error shows `compose-50-bots.yaml` instead of `compose-8421085087-bots.yaml`, meaning MEETING_ID is not being passed correctly.

## Debug Steps

### Step 1: Check Bot Server Logs

**Server 1 par:**

```bash
# Check recent logs
docker logs zoom-bot-server-api --tail 100

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "MEETING_ID="
# - "Using Meeting ID:"
```

### Step 2: Check Script Execution

**Check if scripts are receiving MEETING_ID:**

```bash
# Check if MEETING_ID is in environment
docker exec zoom-bot-server-api env | grep MEETING_ID

# Check script files
docker exec zoom-bot-server-api ls -la /app/bot-project/generate-flexible-bots.sh
docker exec zoom-bot-server-api head -25 /app/bot-project/generate-flexible-bots.sh
```

### Step 3: Test Script Manually

**Test script directly:**

```bash
# SSH to Server 1
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting

# Test generate script
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output file
ls -la compose-*.yaml
```

### Step 4: Check API Code

**Verify meetingId is being passed:**

```bash
# Check bot server API code
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 5 "MEETING_ID"
```

## Quick Fix: Add Debug Logging

Add debug logging to see what's happening:

```bash
# Add debug to bot server
docker exec -it zoom-bot-server-api sh
cd /app/bot-project
# Edit api.js to add more logging
```

## Expected Behavior

**When meetingId="8421085087":**
- Script should receive MEETING_ID="8421085087"
- Compose file should be: `compose-8421085087-bots.yaml`
- Containers should be: `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20`

## Summary

**Check:**
1. Bot server logs for MEETING_ID
2. Script files are updated
3. MEETING_ID environment variable
4. Compose file names generated


# Local Test Steps

## Problem
Error me abhi bhi `compose-50-bots.yaml` dikha raha hai, matlab script execution me issue hai.

## Changes Made

1. ✅ **Added validation** - Check if compose file exists before using it
2. ✅ **Added debug logging** - Log meetingId, composeFileName, and full paths
3. ✅ **Added error handling** - Return clear error if compose file not found

## Local Test Steps

### Step 1: Test Script Manually

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Run test script
./test-local-script.sh

# Check output:
# - Should see: "✅ Found compose-8421085087-bots.yaml"
# - Should NOT see: "compose-50-bots.yaml"
```

### Step 2: Check Bot Server Logs

**Terminal 1 - Start bot server:**

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Start bot server (if not running)
cd bot-server
node api.js
```

**Terminal 2 - Create meeting:**

```bash
curl -X POST http://localhost:3001/api/bots/create \
  -H "Content-Type: application/json" \
  -d '{
    "meetingId":"8421085087",
    "password":"123456",
    "joinUrl":"https://zoom.us/j/8421085087?pwd=123456",
    "videoCount":0,
    "audioCount":20,
    "nameType":"Indian",
    "meetingType":"Normal Member",
    "accountId":"kOjrXedBRwGlbGiCyzQOyQ",
    "clientId":"9bk9CyXgSgqggGe5InpVMA",
    "clientSecret":"OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
  }'
```

### Step 3: Check Logs

**Look for in Terminal 1:**

```
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
📋 Meeting ID type: string
📋 Meeting ID value: "8421085087"
✅ Compose file exists: /path/to/compose-8421085087-bots.yaml
📋 Command to execute: docker-compose -f compose-8421085087-bots.yaml up -d --force-recreate
```

**Should NOT see:**
- `compose-50-bots.yaml`
- `Compose file not found`

### Step 4: Check Generated Files

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Check compose files
ls -la compose-*.yaml

# Should see:
# - compose-8421085087-bots.yaml ✅
# - Should NOT see: compose-50-bots.yaml ❌
```

## Expected Results

✅ **Success:**
- Script generates `compose-8421085087-bots.yaml`
- Logs show correct compose file name
- No `compose-50-bots.yaml` error

❌ **Failure:**
- If still seeing `compose-50-bots.yaml`:
  1. Check logs me `MEETING_ID` properly pass ho raha hai
  2. Check script me `MEETING_ID` environment variable set hai
  3. Check `generate-flexible-bots.sh` me `MEETING_ID` use ho raha hai

## Debug Commands

```bash
# Check MEETING_ID in script
grep -n "MEETING_ID" setup-flexible-bots.sh | head -5

# Check compose file generation
grep -n "COMPOSE_FILE" generate-flexible-bots.sh | head -5

# Test script with MEETING_ID
MEETING_ID="8421085087" bash setup-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "kOjrXedBRwGlbGiCyzQOyQ" "9bk9CyXgSgqggGe5InpVMA" "OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"

# Check generated file
ls -la compose-8421085087-bots.yaml
```

## Next Steps

1. ✅ Test locally first
2. ✅ Verify logs show correct compose file name
3. ✅ Push to server if local test passes
4. ✅ Rebuild bot server container on server
5. ✅ Test on server


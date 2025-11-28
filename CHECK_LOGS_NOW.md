# Check Bot Server Logs - Debug Meeting ID Issue

## Problem
Error shows `compose-50-bots.yaml` instead of `compose-8421085087-bots.yaml`.

## Step 1: Check Bot Server Logs

**Server 1 par ye command run karein:**

```bash
# Check recent logs
docker logs zoom-bot-server-api --tail 200 | grep -E "(MEETING_ID|compose|Meeting ID|Extracted values)"

# Full logs
docker logs zoom-bot-server-api --tail 200
```

**Look for:**
- `📥 Received request body` - Should show meetingId="8421085087"
- `📋 Extracted values` - Should show meetingId
- `MEETING_ID=` - In command execution
- `Using Meeting ID:` - From script output
- `Expected compose file:` - Should show `compose-8421085087-bots.yaml`

## Step 2: Check Generated Files

**Server 1 par:**

```bash
# Check what compose files exist
cd /opt/zoom-headless-meeting
ls -la compose-*.yaml

# Check if old file exists
ls -la compose-50-bots.yaml
```

## Step 3: Test Script Manually

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting

# Test script with meeting ID
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-8421085087-bots.yaml
```

## Step 4: Check Script Files

**Verify scripts are updated:**

```bash
# Check generate script
head -25 generate-flexible-bots.sh | grep -E "(MEETING_ID|compose)"

# Check setup script  
head -80 setup-flexible-bots.sh | grep -E "(MEETING_ID|compose)"
```

## Expected Output

**From logs, you should see:**
```
📥 Received request body: {"meetingId":"8421085087",...}
📋 Extracted values: { meetingId: '8421085087', ... }
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
```

**If you see `compose-50-bots.yaml`, then:**
- Script is not receiving MEETING_ID
- Or script is using old code
- Or there's a fallback to "50" somewhere

## Quick Fix

**If logs show MEETING_ID is not being passed:**

1. Check bot server API code is updated
2. Rebuild bot server container
3. Check script files are updated on server

## Summary

**Check logs first:**
```bash
docker logs zoom-bot-server-api --tail 200
```

Ye logs share karein, phir exact issue identify karte hain.


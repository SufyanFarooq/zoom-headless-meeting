# Fix Compose File Issue

## Problem
Error shows `compose-50-bots.yaml` instead of `compose-8421085087-bots.yaml`.

## Possible Causes

1. **Old compose file exists** - `compose-50-bots.yaml` file might exist and docker-compose is using it
2. **MEETING_ID not passed** - Script is not receiving MEETING_ID properly
3. **Script fallback** - Script is falling back to default value

## Step 1: Check for Old Compose Files

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting

# Check all compose files
ls -la compose-*.yaml

# If compose-50-bots.yaml exists, remove it
rm -f compose-50-bots.yaml

# Check for any old compose files
ls -la compose-*.yaml
```

## Step 2: Test Meeting Creation with Logs

**Terminal 1 - Watch logs:**
```bash
docker logs -f zoom-bot-server-api
```

**Terminal 2 - Create meeting:**
```bash
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

## Step 3: Check Logs Output

**Look for these in logs:**

```
📥 Received request body: {"meetingId":"8421085087",...}
📋 Extracted values: { meetingId: '8421085087', ... }
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
📝 Step 1: Generating compose file...
   Meeting ID from env: 8421085087
   Using Meeting ID: 8421085087
✅ Using Meeting ID: 8421085087
```

**If you see `compose-50-bots.yaml` in logs:**
- MEETING_ID is not being passed correctly
- Or script is using old code

## Step 4: Verify Scripts on Server

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting

# Check generate script
grep -A 2 "COMPOSE_FILE" generate-flexible-bots.sh

# Should show:
# COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"

# Check setup script
grep -A 5 "MEETING_ID" setup-flexible-bots.sh | head -10

# Should show MEETING_ID handling
```

## Step 5: Manual Test Script

**Test script directly:**

```bash
cd /opt/zoom-headless-meeting

# Remove old compose files first
rm -f compose-*.yaml

# Test script
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-*.yaml
# Should see: compose-8421085087-bots.yaml
```

## Step 6: If Still Issues

**Rebuild bot server with latest code:**

```bash
# Stop and remove
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# Ensure latest code
cd /opt/zoom-headless-meeting
git pull origin main

# Rebuild
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# Start
docker run -d --name zoom-bot-server-api -p 3001:3001 -v /opt/zoom-headless-meeting:/app/bot-project -v /var/run/docker.sock:/var/run/docker.sock zoom-headless-meeting-bot-server
```

## Summary

**Quick fix:**
1. Remove old compose files: `rm -f compose-50-bots.yaml`
2. Test meeting creation
3. Check logs for MEETING_ID
4. Verify scripts are updated

**Share logs output after meeting creation attempt.**


# Debug Compose File Issue - Still Using compose-50-bots.yaml

## Problem
Scripts updated hain, lekin abhi bhi `compose-50-bots.yaml` use ho raha hai.

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
# - "Expected compose file:"
# - "Using Meeting ID:"
```

### Step 2: Check if Old Compose File Exists

```bash
cd ~/zoom-headless-meeting

# Check compose files
ls -la compose-*.yaml

# If compose-50-bots.yaml exists, remove it
rm -f compose-50-bots.yaml
```

### Step 3: Check Bot Server Container Volume Mount

```bash
# Check volume mount
docker inspect zoom-bot-server-api | grep -A 10 Mounts

# Should show:
# /home/skylark/zoom-headless-meeting:/app/bot-project
# OR
# /opt/zoom-headless-meeting:/app/bot-project
```

**Important:** Bot server container ko correct path mount hona chahiye (`~/zoom-headless-meeting`).

### Step 4: Test Script Manually

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Test script directly
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-*.yaml
# Should see: compose-8421085087-bots.yaml
# NOT: compose-50-bots.yaml
```

### Step 5: Check Bot Server API Code Path

**Verify bot server is reading from correct path:**

```bash
# Check bot server container
docker exec zoom-bot-server-api ls -la /app/bot-project/generate-flexible-bots.sh

# Check if MEETING_ID support exists
docker exec zoom-bot-server-api grep -n "MEETING_ID" /app/bot-project/generate-flexible-bots.sh | head -3
```

## Possible Issues

1. **Bot server container me old code cached**
   - Solution: Rebuild bot server container

2. **Volume mount path incorrect**
   - Solution: Check mount path matches actual project location

3. **Old compose file exists**
   - Solution: Remove `compose-50-bots.yaml`

4. **Script not receiving MEETING_ID**
   - Solution: Check logs for MEETING_ID value

## Quick Fix

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# 2. Check bot server volume mount
docker inspect zoom-bot-server-api | grep -A 5 Mounts

# 3. Rebuild bot server (if volume mount wrong)
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# Check correct path
pwd
# Should be: /home/skylark/zoom-headless-meeting

# Rebuild with correct path
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# 4. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Check:**
1. Bot server logs for MEETING_ID
2. Old compose files exist
3. Volume mount path correct
4. Bot server container using updated code

**Share bot server logs output!**


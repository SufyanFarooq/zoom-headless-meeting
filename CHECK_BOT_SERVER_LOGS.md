# Check Bot Server Logs - Find Issue

## Problem
Error shows `compose-50-bots.yaml` but code expects `compose-8421085087-bots.yaml`.

## Step 1: Check Bot Server Logs

**Server 1 par:**

```bash
# Check recent logs
docker logs zoom-bot-server-api --tail 200

# Look for these lines:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "MEETING_ID="
# - "Expected compose file:"
# - "Using Meeting ID:"
# - "📋 Generated compose files:"
```

**Important:** Logs me `MEETING_ID` value check karein.

## Step 2: Check Script Execution

**Logs me ye dikhna chahiye:**

```
📥 Received request body: {"meetingId":"8421085087",...}
📋 Extracted values: { meetingId: '8421085087', ... }
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
📝 Step 1: Generating compose file...
   Meeting ID from env: 8421085087
   Using Meeting ID: 8421085087
✅ Using Meeting ID: 8421085087
📋 Generated compose files: compose-8421085087-bots.yaml
```

**Agar logs me `compose-50-bots.yaml` dikhe, to:**
- Script me MEETING_ID properly pass nahi ho raha
- Ya script old code use kar rahi hai

## Step 3: Check Volume Mount

**Verify bot server container correct path use kar raha hai:**

```bash
# Check volume mount
docker inspect zoom-bot-server-api | grep -A 10 Mounts

# Should show:
# /home/skylark/zoom-headless-meeting:/app/bot-project
```

**Agar path galat hai, to rebuild karein:**

```bash
# Stop and remove
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# Rebuild with correct path
cd ~/zoom-headless-meeting
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server
```

## Step 4: Remove Old Compose File

```bash
cd ~/zoom-headless-meeting

# Remove old compose file
rm -f compose-50-bots.yaml

# Verify
ls -la compose-*.yaml
# Should be empty or only new meeting files
```

## Step 5: Test Meeting Creation Again

**Watch logs:**
```bash
docker logs -f zoom-bot-server-api
```

**Create meeting:**
```bash
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Check:**
1. Bot server logs for MEETING_ID value
2. Volume mount path correct
3. Old compose file removed
4. Script execution output

**Share bot server logs output!**


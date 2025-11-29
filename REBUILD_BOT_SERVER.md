# Rebuild Bot Server - Fix Cached Code Issue

## Problem
Bot server container me old code cached hai, isliye `compose-50-bots.yaml` abhi bhi use ho raha hai.

## Solution: Rebuild Bot Server Container

**Server 1 par ye commands:**

### Step 1: Stop and Remove Bot Server

```bash
# Stop bot server
docker stop zoom-bot-server-api

# Remove container
docker rm zoom-bot-server-api
```

### Step 2: Verify Project Path

```bash
# Check current directory
cd ~/zoom-headless-meeting
pwd
# Should be: /home/skylark/zoom-headless-meeting

# Verify scripts are updated
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
grep -n "MEETING_ID" bot-server/api.js | head -3
```

### Step 3: Rebuild Bot Server Container

```bash
# Rebuild image
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# Start container with correct volume mount
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# Verify container started
docker ps | grep zoom-bot-server-api
```

### Step 4: Verify Volume Mount

```bash
# Check volume mount
docker inspect zoom-bot-server-api | grep -A 10 Mounts

# Should show:
# /home/skylark/zoom-headless-meeting:/app/bot-project

# Verify scripts in container
docker exec zoom-bot-server-api ls -la /app/bot-project/generate-flexible-bots.sh
docker exec zoom-bot-server-api grep -n "MEETING_ID" /app/bot-project/generate-flexible-bots.sh | head -3
```

### Step 5: Test Meeting Creation

**Watch logs:**
```bash
docker logs -f zoom-bot-server-api
```

**Create meeting (another terminal):**
```bash
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

**Expected in logs:**
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

## Complete Sequence

**Server 1 par:**

```bash
# 1. Stop and remove
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# 2. Go to project directory
cd ~/zoom-headless-meeting

# 3. Rebuild
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# 4. Start with correct volume
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# 5. Verify
docker logs zoom-bot-server-api --tail 20
docker exec zoom-bot-server-api grep -n "MEETING_ID" /app/bot-project/generate-flexible-bots.sh | head -3

# 6. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Problem:** Bot server container me old code cached  
**Solution:** Rebuild bot server container  
**Result:** Updated code use hoga, `compose-{meetingId}-bots.yaml` generate hoga

Ye steps follow karein, phir test karein!


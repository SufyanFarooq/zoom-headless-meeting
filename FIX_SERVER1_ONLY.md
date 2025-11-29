# Fix Server 1 Only - Multiple Meetings Support

## Current Status
- ✅ Server 1: Capacity 150, Current Load 100 (1 meeting running)
- ✅ Remaining: 50 bots capacity
- ✅ Goal: 2nd meeting (30 bots) should run on Server 1 without disturbing 1st meeting

## Problem
- ❌ Code not updated on Server 1 (scripts need MEETING_ID support)
- ❌ Docker image missing (`zoom-bot:latest`)

## Solution: Update Code on Server 1

### Step 1: Copy Updated Files to Server 1

**Local machine se Server 1 par copy karein:**

**Option A: Using scp**
```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy files to Server 1 (replace SERVER1_IP)
scp generate-flexible-bots.sh user@SERVER1_IP:/opt/zoom-headless-meeting/
scp setup-flexible-bots.sh user@SERVER1_IP:/opt/zoom-headless-meeting/
scp bot-server/api.js user@SERVER1_IP:/opt/zoom-headless-meeting/bot-server/
scp update-compose-zak.py user@SERVER1_IP:/opt/zoom-headless-meeting/
```

**Option B: Using tar.gz package**
```bash
# Local machine par (already created)
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy package
scp updated-scripts.tar.gz user@SERVER1_IP:/tmp/

# Server 1 par extract
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting
tar -xzf /tmp/updated-scripts.tar.gz
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
rm /tmp/updated-scripts.tar.gz
```

### Step 2: Server 1 par Verify

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting

# Verify scripts updated
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
# Should show: MEETING_ID="${7:-}"

grep -n "COMPOSE_FILE" generate-flexible-bots.sh | head -3
# Should show: COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"

# Check bot-server/api.js
grep -n "MEETING_ID" bot-server/api.js | head -3
```

### Step 3: Remove Old Compose Files

```bash
# Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# Verify
ls -la compose-*.yaml
# Should be empty
```

### Step 4: Build Docker Image

```bash
# Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest
```

### Step 5: Restart Bot Server

```bash
# Restart to use updated code
docker restart zoom-bot-server-api

# Check logs
docker logs zoom-bot-server-api --tail 20
```

### Step 6: Test 2nd Meeting

**Current status:**
- Meeting 1: 100 bots running
- Remaining capacity: 50 bots

**Create 2nd meeting (30 bots):**

```bash
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "membersCount": 30,
    "videoCount": 0,
    "audioCount": 30,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Expected result:**
- ✅ 2nd meeting starts on Server 1
- ✅ Total: 130 bots (100 + 30)
- ✅ Remaining capacity: 20 bots
- ✅ Meeting 1 containers: `zoom-bot-{meetingId1}-1` to `zoom-bot-{meetingId1}-100`
- ✅ Meeting 2 containers: `zoom-bot-8421085087-1` to `zoom-bot-8421085087-30`
- ✅ No conflict, both meetings run simultaneously

### Step 7: Verify Containers

```bash
# Check running containers
docker ps | grep zoom-bot

# Should see:
# zoom-bot-{meetingId1}-1 to zoom-bot-{meetingId1}-100 (Meeting 1)
# zoom-bot-8421085087-1 to zoom-bot-8421085087-30 (Meeting 2)

# Check server load
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load FROM bot_servers WHERE server_name = 'server-1';"

# Should show:
# server-1 | 150 | 130
```

## Complete Sequence

**Server 1 par:**

```bash
# 1. Extract files (if using tar.gz)
cd /opt/zoom-headless-meeting
tar -xzf /tmp/updated-scripts.tar.gz
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# 2. Verify
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3

# 3. Remove old files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# 4. Build Docker image
docker build -t zoom-bot:latest . --platform linux/amd64

# 5. Restart bot server
docker restart zoom-bot-server-api

# 6. Test 2nd meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":30,"videoCount":0,"audioCount":30,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Goal:** 2nd meeting (30 bots) Server 1 par without disturbing 1st meeting  
**Fix:** Update code + Build Docker image  
**Result:** Both meetings run simultaneously with unique container names

**Steps:**
1. ✅ Copy updated files to Server 1
2. ✅ Remove old compose files
3. ✅ Build Docker image
4. ✅ Restart bot server
5. ✅ Test 2nd meeting

Ye steps follow karein, dono meetings Server 1 par simultaneously run hongi! ✅


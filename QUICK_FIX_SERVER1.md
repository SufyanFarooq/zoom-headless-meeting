# Quick Fix Server 1 - Both Issues

## Issues
1. ❌ `compose-50-bots.yaml` still being generated
2. ❌ Docker image missing

## Complete Fix Sequence

**Server 1 par ye commands run karein:**

### Step 1: Update Code and Verify Scripts

```bash
cd /opt/zoom-headless-meeting

# Pull latest code
git pull origin main

# Verify scripts are updated
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
grep -n "COMPOSE_FILE" generate-flexible-bots.sh | head -3

# Should show:
# MEETING_ID="${7:-}"
# COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"
```

### Step 2: Remove Old Compose Files

```bash
# Remove all old compose files
rm -f compose-50-bots.yaml
rm -f compose-*-bots.yaml

# Verify
ls -la compose-*.yaml
# Should be empty or no files
```

### Step 3: Build Docker Image

```bash
# Check Dockerfile exists
ls -la Dockerfile

# Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest

# Expected output:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB
```

### Step 4: Restart Bot Server

```bash
# Restart to ensure latest code
docker restart zoom-bot-server-api

# Check logs
docker logs zoom-bot-server-api --tail 20
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

**Expected in logs:**
```
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
✅ Using Meeting ID: 8421085087
📋 Generated compose files: compose-8421085087-bots.yaml
```

**Expected result:**
- ✅ Compose file: `compose-8421085087-bots.yaml`
- ✅ Containers: `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20`
- ✅ No errors

## If Still Issues

**Check bot server logs for MEETING_ID:**

```bash
docker logs zoom-bot-server-api --tail 200 | grep -E "(MEETING_ID|compose|Meeting ID)"
```

**If MEETING_ID not in logs:**
- Scripts not updated
- Or MEETING_ID not being passed correctly

**Manual test script:**
```bash
cd /opt/zoom-headless-meeting

# Test script directly
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-*.yaml
cat compose-8421085087-bots.yaml | head -10
```

## Summary

**Two fixes:**
1. ✅ Update scripts (git pull)
2. ✅ Build Docker image

**Commands:**
```bash
cd /opt/zoom-headless-meeting
git pull origin main
rm -f compose-50-bots.yaml
docker build -t zoom-bot:latest . --platform linux/amd64
docker restart zoom-bot-server-api
```

Ye steps follow karein, phir test karein.


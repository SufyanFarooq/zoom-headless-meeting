# Fix: compose-50-bots.yaml Issue

## Problem
Error me abhi bhi `compose-50-bots.yaml` dikha raha hai, matlab scripts me hardcoded file name hai.

## Root Cause
1. `auto-setup-bots.sh` me hardcoded `compose-50-bots.yaml` tha
2. `auto-setup-bots.sh` ko `COMPOSE_FILE` environment variable pass nahi ho raha tha
3. Python script inside `auto-setup-bots.sh` sirf `bot-{NUM}` format handle kar raha tha, `bot-{MEETING_ID}-{NUM}` nahi

## Fixes Applied

### 1. Updated `auto-setup-bots.sh`
- ✅ `COMPOSE_FILE` environment variable support add kiya
- ✅ Fallback to `compose-50-bots.yaml` if not set
- ✅ `update-compose-zak.py` calls me `COMPOSE_FILE` pass kiya
- ✅ Python script me meeting-specific bot names support add kiya

### 2. Updated `setup-flexible-bots.sh`
- ✅ `COMPOSE_FILE` environment variable set kiya before calling `auto-setup-bots.sh`
- ✅ `MEETING_ID` se compose file name generate kiya

### 3. Updated `update-compose-zak.py`
- ✅ Already supports command line argument (no changes needed)

## Testing Steps

### Step 1: Copy Updated Files to Server 1

**Local machine se:**

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Create package with updated files
tar -czf fix-compose-file.tar.gz \
  auto-setup-bots.sh \
  setup-flexible-bots.sh \
  update-compose-zak.py \
  bot-server/api.js

# Upload to Server 1 (use your method)
# Option 1: Browser SSH upload
# Option 2: git pull on Server 1
# Option 3: scp (if SSH works)
```

### Step 2: Update Files on Server 1

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Extract files (if uploaded via tar)
tar -xzf fix-compose-file.tar.gz

# OR git pull (if using git)
git pull origin main

# Make scripts executable
chmod +x auto-setup-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Verify files updated
grep -n "COMPOSE_FILE" auto-setup-bots.sh | head -3
grep -n "COMPOSE_FILE" setup-flexible-bots.sh | head -3
```

### Step 3: Rebuild Bot Server Container

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Stop bot server
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# Rebuild bot server image
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# Start bot server
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# Check logs
docker logs -f zoom-bot-server-api
```

### Step 4: Test Meeting Creation

**Local machine se:**

```bash
# Get auth token first
TOKEN="your_token_here"

# Create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "meetingId":"8421085087",
    "password":"123456",
    "membersCount":20,
    "videoCount":0,
    "audioCount":20,
    "nameType":"Indian",
    "meetingType":"Normal Member"
  }'
```

### Step 5: Check Logs

**Server 1 par:**

```bash
# Check bot server logs
docker logs -f zoom-bot-server-api

# Look for:
# - "Using Meeting ID: 8421085087"
# - "Expected compose file: compose-8421085087-bots.yaml"
# - "Using compose file: /app/bot-project/compose-8421085087-bots.yaml"
# - NO "compose-50-bots.yaml" in logs

# Check generated compose files
ls -la compose-*.yaml
# Should see: compose-8421085087-bots.yaml
# Should NOT see: compose-50-bots.yaml
```

## Expected Results

✅ **Success:**
- Logs me `compose-8421085087-bots.yaml` dikhega
- `compose-8421085087-bots.yaml` file generate hogi
- Containers `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20` names se start honge
- NO `compose-50-bots.yaml` error

❌ **Failure:**
- Agar abhi bhi `compose-50-bots.yaml` dikhe, to:
  1. Check scripts updated hain
  2. Check bot server container rebuilt hai
  3. Check logs me `MEETING_ID` properly pass ho raha hai

## Summary

**Files Updated:**
- ✅ `auto-setup-bots.sh` - COMPOSE_FILE support
- ✅ `setup-flexible-bots.sh` - COMPOSE_FILE pass kiya
- ✅ `update-compose-zak.py` - Already supports argument (no changes)

**Next Steps:**
1. Copy files to Server 1
2. Rebuild bot server container
3. Test meeting creation
4. Verify logs me correct compose file name dikhe


# Fix Server 1 - Docker Image Missing (URGENT)

## Problem
Server 1 par `zoom-bot:latest` Docker image nahi hai, isliye containers start nahi ho rahe.

**Error:** `pull access denied for zoom-bot, repository does not exist`

## Current Status
- ✅ 100 bots already running (pehli meeting)
- ❌ Docker image missing (nayi meeting start nahi ho rahi)
- ✅ Capacity: 150 bots

## Solution: Server 1 par Image Build Karein

### Step 1: Check Server 1 par Dockerfile

**Server 1 par SSH karein:**

```bash
# Server 1 par SSH
ssh user@SERVER1_IP

# Check directory
cd /opt/zoom-headless-meeting
pwd

# Check Dockerfile
ls -la Dockerfile
```

**Agar Dockerfile nahi hai, to:**

### Step 2: Copy Dockerfile to Server 1

**Local machine se (yahan se):**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy Dockerfile to Server 1
scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/
```

### Step 3: Build Image on Server 1

**Server 1 par:**

```bash
# Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest

# Expected output:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB
```

### Step 4: Test Meeting Creation

**After image build:**

```bash
# Meeting create karein
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "timeoutSeconds": 7200
  }'
```

**Expected:** Success! 20 bots start ho jayenge.

## Background Build (Optional)

**Agar build time zyada hai:**

```bash
# Background build
nohup docker build -t zoom-bot:latest . --platform linux/amd64 > build.log 2>&1 &

# Progress check
tail -f build.log

# Check if running
ps aux | grep docker build
```

## Complete Sequence

**Local Machine:**
```bash
# Copy Dockerfile
scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/
```

**Server 1:**
```bash
# Verify Dockerfile
cd /opt/zoom-headless-meeting
ls -la Dockerfile

# Build image
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest
```

**After Build:**
- Meeting create karein
- 20 bots start ho jayenge
- Total: 120 bots (100 + 20)

## Summary

**Problem:** Server 1 par Docker image missing  
**Solution:** Server 1 par image build karein  
**Time:** 10-30 minutes  
**Commands:**
- Local: `scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/`
- Server 1: `docker build -t zoom-bot:latest . --platform linux/amd64`


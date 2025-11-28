# Quick Fix - Server 1 Docker Image (URGENT)

## Current Situation
- ✅ 100 bots running (Meeting 1: 5067498331)
- ❌ Docker image missing (Meeting 2: 8421085087 start nahi ho rahi)
- ❌ Error: `pull access denied for zoom-bot`

## Immediate Fix: Server 1 par Image Build

### Step 1: Check Server 1

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

**Agar Dockerfile nahi hai:**

### Step 2: Copy Dockerfile

**Local machine se:**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy Dockerfile
scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/
```

### Step 3: Build Image

**Server 1 par:**

```bash
# Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest
```

### Step 4: Test Meeting 2

**After build:**

```bash
# Meeting 2 create karein
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

## Background Build

**Agar build time zyada hai:**

```bash
# Background build
nohup docker build -t zoom-bot:latest . --platform linux/amd64 > build.log 2>&1 &

# Progress check
tail -f build.log

# Check status
ps aux | grep docker build
```

## After Image Build

**Expected Result:**
- Meeting 1: 100 bots (running)
- Meeting 2: 20 bots (start ho jayenge)
- Total: 120 bots (within capacity 150)

## Note: Container Naming

**Current:** Containers `zoom-bot-1` to `zoom-bot-N` se name hote hain  
**Issue:** Multiple meetings me same names conflict create karte hain  
**Future Fix:** Meeting ID based naming (`zoom-bot-{meetingId}-{botNumber}`)

**For now:** Image build karein, meeting start ho jayegi.

## Summary

**Problem:** Server 1 par Docker image missing  
**Solution:** Server 1 par image build karein  
**Time:** 10-30 minutes  
**Commands:**
- Local: `scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/`
- Server 1: `docker build -t zoom-bot:latest . --platform linux/amd64`


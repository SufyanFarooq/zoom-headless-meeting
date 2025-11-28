# Fix Server 2 Image - Step by Step

## Problem
- Server 2 par `zoom-bot:latest` image nahi hai
- Server 2 par `Dockerfile` nahi hai (bot-only package)
- Image Server 1 se copy karni hogi

## Solution: Server 1 se Image Copy Karein

### Step 1: Server 1 par Image Check Karein

**Server 1 par SSH karein aur ye commands run karein:**

```bash
# Check if image exists
docker images | grep zoom-bot

# Expected output:
# zoom-bot   latest   abc123def456   2 hours ago   1.2GB
```

**Agar image nahi hai Server 1 par, to build karein:**

```bash
cd /opt/zoom-headless-meeting
docker build -t zoom-bot:latest .
# Takes 10-30 minutes
```

### Step 2: Server 1 par Image Save Karein

**Server 1 par:**

```bash
# Image save karein
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Size check
ls -lh zoom-bot-image.tar.gz
# Expected: ~500MB-2GB
```

### Step 3: Server 1 se Server 2 par Copy Karein

**Option A: Using gcloud (Server 1 par run karein)**

```bash
# Server 1 par (gcloud configured hona chahiye)
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

**Option B: Using Browser SSH Upload (Easiest)**

1. **Server 1 par file download karein:**
   ```bash
   # Server 1 par
   ls -lh zoom-bot-image.tar.gz
   # File download karein (Browser SSH se)
   ```

2. **Server 2 par Browser SSH se upload karein:**
   - GCP Console → Compute Engine → VM Instances
   - `zoom-bots-server` → SSH (Browser)
   - Upload file → `/tmp/zoom-bot-image.tar.gz`

**Option C: Using scp (Server 1 par run karein)**

```bash
# Server 1 par
scp zoom-bot-image.tar.gz sufyanmaviya400@35.227.36.166:/tmp/
```

### Step 4: Server 2 par Image Load Karein

**Server 2 par (current terminal me):**

```bash
# Check file exists
ls -lh /tmp/zoom-bot-image.tar.gz

# Image load karein
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify image loaded
docker images zoom-bot:latest

# Expected output:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## Complete Sequence

### Server 1 Commands:

```bash
# 1. Check image
docker images | grep zoom-bot

# 2. Save image
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# 3. Check size
ls -lh zoom-bot-image.tar.gz

# 4. Copy to Server 2 (choose one method)
# Method A: gcloud
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c

# Method B: Browser SSH Upload (recommended)
# Download file from Server 1, then upload to Server 2 via Browser SSH
```

### Server 2 Commands (Current Terminal):

```bash
# 1. Check file exists
ls -lh /tmp/zoom-bot-image.tar.gz

# 2. Load image
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# 3. Verify
docker images zoom-bot:latest

# 4. Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## After Image Load, Test

```bash
# Meeting create karein
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Expected:** Success! Containers start ho jayenge.

## Summary

**Current:** Server 2 par image nahi hai  
**Solution:** Server 1 se image copy karein  
**Method:** Browser SSH Upload (easiest)  
**Commands:**
- Server 1: `docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz`
- Upload via Browser SSH
- Server 2: `gunzip -c /tmp/zoom-bot-image.tar.gz | docker load`


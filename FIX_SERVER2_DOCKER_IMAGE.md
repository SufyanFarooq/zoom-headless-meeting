# Fix Server 2 - Missing Docker Image

## Problem

Server 2 par `zoom-bot:latest` Docker image nahi hai, isliye containers start nahi ho rahe.

**Error:** `pull access denied for zoom-bot, repository does not exist`

## Solution Options

### Option 1: Server 1 se Image Copy (Fastest) ⭐

**Step 1: Server 1 par Image Save Karein**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# Image save karein
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Size check karein
ls -lh zoom-bot-image.tar.gz
# Expected: ~500MB-2GB (depends on image size)
```

**Step 2: Server 2 par Copy Karein**

**Using gcloud:**
```bash
# Server 1 se Server 2 par copy
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

**Using scp:**
```bash
scp zoom-bot-image.tar.gz user@35.227.36.166:/tmp/
```

**Browser SSH Upload:**
1. Server 1 se `zoom-bot-image.tar.gz` download karein
2. Browser SSH se Server 2 par upload karein
3. `/tmp/` me upload karein

**Step 3: Server 2 par Load Karein**

```bash
# Server 2 par SSH karein
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Image load karein
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify
docker images | grep zoom-bot

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

### Option 2: Server 2 par Build Karein (Takes Time)

**Server 2 par image build karein:**

```bash
# Server 2 par SSH karein
cd /opt/zoom-headless-meeting

# Image build karein (10-30 minutes lag sakta hai)
docker build -t zoom-bot:latest .

# Verify
docker images | grep zoom-bot
```

**Note:** Build me time lag sakta hai (10-30 minutes), lekin Server 1 se copy karna faster hai.

### Option 3: Using Docker Registry (If Available)

**Agar Docker registry use kar rahe hain:**

```bash
# Server 1 par
docker tag zoom-bot:latest your-registry/zoom-bot:latest
docker push your-registry/zoom-bot:latest

# Server 2 par
docker pull your-registry/zoom-bot:latest
docker tag your-registry/zoom-bot:latest zoom-bot:latest
```

## Quick Fix Commands (Copy-Paste)

### On Server 1:

```bash
# Image save karein
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Size check
ls -lh zoom-bot-image.tar.gz
```

### Copy to Server 2:

**Using gcloud:**
```bash
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

**Using Browser SSH:**
- Upload `zoom-bot-image.tar.gz` to Server 2

### On Server 2:

```bash
# Image load karein
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify
docker images | grep zoom-bot

# Expected output:
# zoom-bot   latest   abc123def456   2 hours ago   1.2GB

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## Complete Sequence (One Go)

### Server 1:

```bash
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

### Server 2:

```bash
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load && \
docker images | grep zoom-bot && \
rm /tmp/zoom-bot-image.tar.gz
```

## Verify Image Exists

```bash
# Server 2 par
docker images zoom-bot:latest

# Expected:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB
```

## Test After Fix

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

## Troubleshooting

### Image Load Failed?

```bash
# Check file integrity
file /tmp/zoom-bot-image.tar.gz
# Expected: gzip compressed data

# Try without gunzip
docker load < /tmp/zoom-bot-image.tar.gz
```

### Image Size Too Large?

**Split large image:**
```bash
# Server 1 par split
split -b 500M zoom-bot-image.tar.gz zoom-bot-image.tar.gz.part

# Copy parts
gcloud compute scp zoom-bot-image.tar.gz.part* zoom-bots-server:/tmp/ --zone=us-east1-c

# Server 2 par combine
cat /tmp/zoom-bot-image.tar.gz.part* > /tmp/zoom-bot-image.tar.gz
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load
```

### Build Instead of Copy?

**Server 2 par build karein:**
```bash
cd /opt/zoom-headless-meeting
docker build -t zoom-bot:latest .
# Takes 10-30 minutes
```

## Summary

**Problem:** Server 2 par `zoom-bot:latest` image missing  
**Solution:** Server 1 se image copy karein (fastest)  
**Commands:**
```bash
# Server 1: docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz
# Copy to Server 2
# Server 2: gunzip -c /tmp/zoom-bot-image.tar.gz | docker load
```

Ye steps follow karein, image Server 2 par load ho jayega! ✅


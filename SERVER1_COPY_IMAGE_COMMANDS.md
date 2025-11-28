# Server 1 Commands - Copy Image to Server 2

## Step 1: Check Image Exists on Server 1

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# Check if image exists
docker images | grep zoom-bot

# Expected output:
# zoom-bot   latest   abc123def456   2 hours ago   1.2GB
```

## Step 2: Save Image

```bash
# Image save karein (compressed)
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Size check karein
ls -lh zoom-bot-image.tar.gz
# Expected: ~500MB-2GB (depends on image size)
```

## Step 3: Copy to Server 2

### Option A: Using gcloud (GCP Server 2)

```bash
# Copy to GCP Server 2
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

### Option B: Using scp

```bash
# Copy to Server 2
scp zoom-bot-image.tar.gz sufyanmaviya400@35.227.36.166:/tmp/
```

### Option C: Browser SSH Upload

1. Server 1 se `zoom-bot-image.tar.gz` download karein
2. GCP Browser SSH se Server 2 par upload karein (`/tmp/` me)

## Step 4: Load Image on Server 2

**Server 2 par ye commands run karein:**

```bash
# Image load karein
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify
docker images | grep zoom-bot

# Expected:
# zoom-bot   latest   abc123def456   2 hours ago   1.2GB

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## Complete Sequence (Server 1)

```bash
# Step 1: Check image
docker images | grep zoom-bot

# Step 2: Save image
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Step 3: Check size
ls -lh zoom-bot-image.tar.gz

# Step 4: Copy to Server 2 (choose one)
# Option A: gcloud
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c

# Option B: scp
scp zoom-bot-image.tar.gz sufyanmaviya400@35.227.36.166:/tmp/

# Step 5: Load on Server 2 (run on Server 2)
# gunzip -c /tmp/zoom-bot-image.tar.gz | docker load
```

## If Image Doesn't Exist on Server 1

**Agar Server 1 par bhi image nahi hai, to build karein:**

```bash
# Server 1 par build karein
cd /opt/zoom-headless-meeting
docker build -t zoom-bot:latest .

# Phir save karein
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz
```

## Quick One-Liner (Server 1)

```bash
docker images | grep zoom-bot && \
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz && \
ls -lh zoom-bot-image.tar.gz && \
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

## Summary

**Server 1 Commands:**
1. ✅ Check: `docker images | grep zoom-bot`
2. ✅ Save: `docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz`
3. ✅ Copy: `gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c`

**Server 2 Commands:**
1. ✅ Load: `gunzip -c /tmp/zoom-bot-image.tar.gz | docker load`
2. ✅ Verify: `docker images | grep zoom-bot`
3. ✅ Cleanup: `rm /tmp/zoom-bot-image.tar.gz`

Ye commands Server 1 par run karein! ✅


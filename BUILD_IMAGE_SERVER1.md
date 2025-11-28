# Build Image on Server 1 - Step by Step

## Problem
Server 1 par `zoom-bot:latest` image nahi hai, isliye save nahi ho rahi.

## Solution: Server 1 par Image Build Karein

### Step 1: Check Current Directory

**Server 1 par:**

```bash
# Check current directory
pwd
# Expected: /opt/zoom-headless-meeting

# Check Dockerfile exists
ls -la Dockerfile

# Check project structure
ls -la
```

### Step 2: Build Image

**Server 1 par:**

```bash
# Build image (takes 10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Monitor progress
# This will show build steps
```

**Build Time:**
- **2-4 cores:** 20-30 minutes
- **8+ cores:** 10-15 minutes
- **RAM:** 4GB+ recommended

### Step 3: Verify Image Built

**After build completes:**

```bash
# Check image exists
docker images zoom-bot:latest

# Expected output:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB
```

### Step 4: Save Image

**Server 1 par:**

```bash
# Save image
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Check size
ls -lh zoom-bot-image.tar.gz
# Expected: ~500MB-2GB
```

### Step 5: Copy to Server 2

**Option A: Using gcloud (Server 1 par)**

```bash
# Copy to Server 2
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

**Option B: Browser SSH Upload**

1. **Server 1 par:** File download karein (Browser SSH se)
2. **Server 2 par:** Browser SSH → Upload file → `/tmp/zoom-bot-image.tar.gz`

**Option C: Using scp**

```bash
scp zoom-bot-image.tar.gz sufyanmaviya400@35.227.36.166:/tmp/
```

### Step 6: Server 2 par Load

**Server 2 par:**

```bash
# Load image
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify
docker images zoom-bot:latest

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## Complete Sequence

### Server 1 Commands:

```bash
# 1. Check directory
cd /opt/zoom-headless-meeting
pwd

# 2. Check Dockerfile
ls -la Dockerfile

# 3. Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# 4. Verify build
docker images zoom-bot:latest

# 5. Save image
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# 6. Check size
ls -lh zoom-bot-image.tar.gz

# 7. Copy to Server 2 (choose one)
# Method A: gcloud
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c

# Method B: Browser SSH Upload
# Download file, then upload to Server 2
```

### Server 2 Commands:

```bash
# 1. Load image
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# 2. Verify
docker images zoom-bot:latest

# 3. Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

## Troubleshooting

### If Build Fails

**Check Dockerfile:**
```bash
cat Dockerfile
```

**Check disk space:**
```bash
df -h
```

**Check Docker:**
```bash
docker info
```

### If Build Takes Too Long

- Build background me run karein: `nohup docker build -t zoom-bot:latest . --platform linux/amd64 > build.log 2>&1 &`
- Progress check: `tail -f build.log`

## Summary

**Current:** Server 1 par image nahi hai  
**Solution:** Server 1 par image build karein  
**Time:** 10-30 minutes  
**Commands:**
- Server 1: `docker build -t zoom-bot:latest . --platform linux/amd64`
- Server 1: `docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz`
- Copy to Server 2
- Server 2: `gunzip -c /tmp/zoom-bot-image.tar.gz | docker load`


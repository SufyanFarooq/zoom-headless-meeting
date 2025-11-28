# Check and Load Image on Server 2

## Current Status

**Warning:** Normal hai, ignore karein. Agar output empty hai, to image nahi hai.

## Check Image Status

```bash
# Check if image exists (better command)
docker images zoom-bot:latest

# Ya format use karein
docker images zoom-bot:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

**Agar output empty hai:** Image nahi hai, load karni hogi.

## Load Image on Server 2

### Option 1: Server 1 se Image Copy Karein (Recommended)

**Server 1 par:**
```bash
# Image save karein
docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz

# Copy to Server 2
gcloud compute scp zoom-bot-image.tar.gz zoom-bots-server:/tmp/ --zone=us-east1-c
```

**Server 2 par:**
```bash
# Image load karein
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load

# Verify
docker images zoom-bot:latest

# Cleanup
rm /tmp/zoom-bot-image.tar.gz
```

### Option 2: Browser SSH Upload

**Step 1: Server 1 se Image Download**
- Server 1 par image save karein
- Download karein

**Step 2: Server 2 par Upload**
- Browser SSH → Upload file
- `/tmp/zoom-bot-image.tar.gz` upload karein

**Step 3: Load**
```bash
gunzip -c /tmp/zoom-bot-image.tar.gz | docker load
docker images zoom-bot:latest
rm /tmp/zoom-bot-image.tar.gz
```

### Option 3: Build on Server 2 (Takes Time)

**Agar Server 1 se copy nahi kar sakte:**

```bash
cd /opt/zoom-headless-meeting
docker build -t zoom-bot:latest .
# Takes 10-30 minutes
```

## Verify Image Loaded

```bash
# Check image
docker images zoom-bot:latest

# Expected output:
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# zoom-bot     latest    abc123def456   2 hours ago    1.2GB
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

**Current:** Image check kiya, warning normal hai  
**Next:** Server 1 se image copy karein aur Server 2 par load karein  
**Commands:**
```bash
# Server 1: docker save zoom-bot:latest | gzip > zoom-bot-image.tar.gz
# Copy to Server 2
# Server 2: gunzip -c /tmp/zoom-bot-image.tar.gz | docker load
```


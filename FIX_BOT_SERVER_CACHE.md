# Fix Bot Server Cache Issue

## Problem
After `git pull` and `docker restart`, bot server is still using old code that generates `compose-50-bots.yaml` instead of `compose-{meetingId}-bots.yaml`.

## Solution: Rebuild Bot Server Container

The bot server container might have cached code. Rebuild it to use the latest code.

### Option 1: Rebuild Container (Recommended)

**Server 1 par:**

```bash
# Stop bot server
docker stop zoom-bot-server-api

# Remove container
docker rm zoom-bot-server-api

# Rebuild and start
cd /opt/zoom-headless-meeting
docker-compose -f docker-compose.bot-server.yml up -d --build
```

### Option 2: Check Volume Mount

**If code is mounted as volume, ensure it's updated:**

```bash
# Check if code is mounted
docker inspect zoom-bot-server-api | grep -A 10 Mounts

# If mounted, ensure latest code is in the mount directory
cd /opt/zoom-headless-meeting
git status
git pull origin main
```

### Option 3: Force Container Restart with Code Refresh

**If using volume mount:**

```bash
# Restart with force
docker restart zoom-bot-server-api

# Check logs
docker logs zoom-bot-server-api --tail 50
```

## Verify Fix

**After rebuild, check logs:**

```bash
# Check bot server logs
docker logs zoom-bot-server-api --tail 100

# Look for:
# - "Using Meeting ID: 8421085087"
# - "compose-8421085087-bots.yaml"
```

**Test meeting creation:**

```bash
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
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

**Expected:** Should use `compose-8421085087-bots.yaml` and containers `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20`

## Summary

**Problem:** Bot server using cached old code  
**Solution:** Rebuild bot server container  
**Commands:**
```bash
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api
cd /opt/zoom-headless-meeting
docker-compose -f docker-compose.bot-server.yml up -d --build
```


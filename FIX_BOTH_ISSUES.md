# Fix Both Issues: compose-50-bots.yaml + Docker Image

## Issues

1. ❌ Error me `compose-50-bots.yaml` dikha raha hai (logs print nahi ho rahe)
2. ❌ "pull access denied for zoom-bot" - Docker image missing

## Problem Analysis

**Issue 1:** Logs print nahi ho rahe matlab:
- Script execution start nahi ho rahi
- Ya error pehle hi catch ho raha hai
- Ya logs capture nahi ho rahe

**Issue 2:** Docker image missing:
- `zoom-bot:latest` image server par nahi hai
- Docker-compose image pull karne ki koshish kar raha hai
- Image build karni hogi

## Solution

### Step 1: Check if Request is Reaching Bot Server

**Server 1 par:**

```bash
# Check if request is received
docker logs zoom-bot-server-api --tail 50 | grep -E "(Received request|Extracted values|Creating bots)"

# If no logs, check if container is running
docker ps | grep zoom-bot-server-api
```

### Step 2: Build Docker Image

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Build zoom-bot image
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify image exists
docker images | grep zoom-bot

# Should see:
# zoom-bot    latest    ...    ...    ...    ✅
```

### Step 3: Check Full Logs Without Filter

**Server 1 par:**

```bash
# Get ALL logs (no grep)
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "Creating bots"
# - "⏳ Executing setup script"
# - Any error messages
```

### Step 4: Restart Container and Test

**Server 1 par:**

```bash
# Restart container
docker restart zoom-bot-server-api

# Wait a few seconds
sleep 3

# Check logs
docker logs zoom-bot-server-api --tail 20

# Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Immediately check logs
docker logs zoom-bot-server-api --tail 100
```

## Quick Fix Commands

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Build Docker image
docker build -t zoom-bot:latest . --platform linux/amd64

# 2. Verify image
docker images | grep zoom-bot

# 3. Restart bot server
docker restart zoom-bot-server-api

# 4. Clear old logs and test
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 5. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 6. Check ALL logs (no filter)
docker logs zoom-bot-server-api --tail 200
```

## Expected Results

✅ **After building image:**
- `docker images | grep zoom-bot` me image dikhega
- "pull access denied" error nahi aayega

✅ **After fixing:**
- Logs me "📥 Received request body" dikhega
- Logs me "📋 Expected compose file: compose-8421085087-bots.yaml" dikhega
- NO `compose-50-bots.yaml` error

## If Still Failing

**Check:**
1. Full logs without grep - `docker logs zoom-bot-server-api --tail 200`
2. Container status - `docker ps | grep zoom-bot-server-api`
3. Image exists - `docker images | grep zoom-bot`
4. Request reaching - Check logs for "Received request"

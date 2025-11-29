# Debug No Logs Issue

## Problem
Bot server logs me sirf startup message dikha raha hai, request logs nahi aa rahe.

## Debug Steps

### Step 1: Check if Request Reaches Bot Server

**Test bot server directly:**

```bash
# Test bot server health
curl http://localhost:3001/health

# Test bot server create endpoint directly
curl -X POST http://localhost:3001/api/bots/create \
  -H "Content-Type: application/json" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "joinUrl": "https://zoom.us/j/8421085087?pwd=123456",
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "accountId": "YOUR_ACCOUNT_ID",
    "clientId": "YOUR_CLIENT_ID",
    "clientSecret": "YOUR_CLIENT_SECRET"
  }'
```

**Watch logs while testing:**
```bash
docker logs -f zoom-bot-server-api
```

### Step 2: Check Container Logs Format

**Check if logs are being captured:**

```bash
# Check all logs
docker logs zoom-bot-server-api

# Check with timestamps
docker logs -t zoom-bot-server-api

# Check last 100 lines
docker logs zoom-bot-server-api --tail 100
```

### Step 3: Check Bot Server Container

**Verify container is running correctly:**

```bash
# Check container status
docker ps | grep zoom-bot-server-api

# Check container logs
docker logs zoom-bot-server-api 2>&1

# Check if request is reaching
docker exec zoom-bot-server-api ps aux | grep node
```

### Step 4: Check API Server Logs

**Check API server logs (where request originates):**

```bash
# Check API server logs
docker logs zoom-dashboard-api --tail 100

# Look for:
# - "📤 Sending request to bot server"
# - "Bot server error"
# - Request details
```

### Step 5: Manual Test Script

**Test script directly on server:**

```bash
cd ~/zoom-headless-meeting

# Test script with MEETING_ID
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-*.yaml
# Should see: compose-8421085087-bots.yaml
```

## Possible Issues

1. **Request not reaching bot server**
   - Check API server logs
   - Check bot server URL in database

2. **Logs buffered**
   - Wait a few seconds after request
   - Check logs again

3. **Container logs not capturing**
   - Restart container
   - Check docker logs command

## Quick Test

**Server 1 par:**

```bash
# 1. Check API server logs
docker logs zoom-dashboard-api --tail 50

# 2. Test bot server directly
curl http://localhost:3001/health

# 3. Watch bot server logs
docker logs -f zoom-bot-server-api

# 4. Create meeting via API (another terminal)
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Check:**
1. API server logs (request origin)
2. Bot server health endpoint
3. Direct bot server test
4. Container logs format

**Share API server logs output!**


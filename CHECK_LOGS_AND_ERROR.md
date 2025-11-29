# Check Logs and Error Source

## Problem
Request bheji hai, lekin koi log print nahi hua. Error me `compose-50-bots.yaml` dikha raha hai.

## Debug Steps

### Step 1: Check Bot Server Logs (NO filter)

**Server 1 par:**

```bash
# Get ALL bot server logs
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "Creating bots"
# - "⏳ Executing setup script"
# - Any error messages
```

### Step 2: Check Main API Logs (NO filter)

**Server 1 par:**

```bash
# Get ALL main API logs
docker logs zoom-dashboard-api --tail 200

# Look for:
# - "📤 Sending request to bot server"
# - "🔧 Fixed bot server URL"
# - "Error creating bots"
# - Full error stack trace
```

### Step 3: Check if Request Reaches Bot Server

**Server 1 par:**

```bash
# Clear logs first
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# Watch logs in real-time
docker logs -f zoom-bot-server-api

# In another terminal, create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Check Terminal 1 - dekho kya logs aate hain
```

### Step 4: Check Error Source

**Server 1 par:**

```bash
# Check main API error handling
docker exec zoom-dashboard-api cat /app/api/services/botService.js | grep -A 5 -B 5 "Bot server error"

# Check line 286 (error handling)
docker exec zoom-dashboard-api sed -n '284,290p' /app/api/services/botService.js
```

## Possible Issues

1. **Error cached** - Old error message cached hai
2. **Request not reaching** - Bot server tak request nahi pahunch raha
3. **Logs not capturing** - Logs capture nahi ho rahe
4. **Error from previous execution** - Error kisi previous execution se hai

## Quick Test

**Server 1 par:**

```bash
# 1. Stop and restart bot server (to clear any cached state)
docker restart zoom-bot-server-api

# 2. Wait a few seconds
sleep 3

# 3. Clear all logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 4. Watch bot server logs
docker logs -f zoom-bot-server-api

# 5. In another terminal, create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 6. Check Terminal 1 - dekho kya logs aate hain
```

## Expected Results

✅ **If request reaches bot server:**
- Logs me "📥 Received request body" dikhega
- Logs me "📋 Expected compose file: compose-8421085087-bots.yaml" dikhega
- NO `compose-50-bots.yaml` in logs

❌ **If request NOT reaching:**
- No logs at all
- Error from main API, not bot server
- Check network connectivity


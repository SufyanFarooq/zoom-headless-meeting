# Debug Request Flow - compose-50-bots.yaml Error

## Current Status

✅ Database URL correct: `http://bot-server:3001`
❌ Error me `compose-50-bots.yaml` dikha raha hai
❌ Bot server logs me kuch nahi dikha raha

## Debug Steps

### Step 1: Check Main API Logs (NO grep)

**Server 1 par:**

```bash
# Get ALL main API logs (no filter)
docker logs zoom-dashboard-api --tail 200

# Look for:
# - "📤 Sending request to bot server"
# - "🔧 Fixed bot server URL"
# - "Error creating bots"
# - Full error stack trace
```

### Step 2: Check Bot Server Logs (NO grep)

**Server 1 par:**

```bash
# Get ALL bot server logs (no filter)
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "Creating bots"
# - "⏳ Executing setup script"
# - Any error messages
```

### Step 3: Test Direct Bot Server Call

**Server 1 par:**

```bash
# Clear bot server logs first
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# Test direct call from main API container
docker exec zoom-dashboard-api curl -X POST http://bot-server:3001/api/bots/create \
  -H "Content-Type: application/json" \
  -d '{
    "meetingId":"8421085087",
    "password":"123456",
    "joinUrl":"https://zoom.us/j/8421085087?pwd=123456",
    "videoCount":0,
    "audioCount":20,
    "nameType":"Indian",
    "meetingType":"Normal Member",
    "accountId":"kOjrXedBRwGlbGiCyzQOyQ",
    "clientId":"9bk9CyXgSgqggGe5InpVMA",
    "clientSecret":"OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
  }'

# Check bot server logs
docker logs zoom-bot-server-api --tail 100
```

### Step 4: Check Error Source

**Server 1 par:**

```bash
# Check main API error handling
docker exec zoom-dashboard-api cat /app/api/services/botService.js | grep -A 5 -B 5 "Bot server error"

# Check line 262 (where error occurs)
docker exec zoom-dashboard-api sed -n '260,270p' /app/api/services/botService.js
```

## Possible Issues

1. **Error cached** - Old error message cached hai
2. **Request not reaching** - Bot server tak request nahi pahunch raha
3. **Error from previous execution** - Error kisi previous execution se hai
4. **Logs not capturing** - Logs capture nahi ho rahe

## Quick Test

**Server 1 par:**

```bash
# 1. Clear all logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 2. Watch bot server logs in real-time
docker logs -f zoom-bot-server-api

# 3. In another terminal, create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 4. Check what appears in bot server logs
# Should see: "📥 Received request body"
```


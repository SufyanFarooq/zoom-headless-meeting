# Debug API Error - compose-50-bots.yaml

## Problem
Manually script perfect kaam kar rahi hai, lekin API se call karne par `compose-50-bots.yaml` error aa raha hai.

## Analysis

**Manually working:**
- Script execution sahi hai
- Compose file generate ho rahi hai
- Docker-compose command sahi hai

**API failing:**
- Error me `compose-50-bots.yaml` dikha raha hai
- Logs print nahi ho rahe

## Possible Causes

1. **Error from previous execution** - Old error cached
2. **Error message format** - Error.message me old command
3. **Request not reaching bot server** - API call fail ho raha hai
4. **Error from different code path** - Koi aur code path use ho raha hai

## Debug Steps

### Step 1: Check if Request Reaches Bot Server

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

# Check what logs appear
```

### Step 2: Check Full Logs

**Server 1 par:**

```bash
# Get ALL logs (no filter)
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "Creating bots"
# - "⏳ Executing setup script"
# - "📋 Expected compose file"
# - "📋 Command to execute"
```

### Step 3: Check Error Source

**Server 1 par:**

```bash
# Check if error is from bot server or main API
# Main API logs check karein
docker logs zoom-dashboard-api --tail 100 | grep -E "(Bot server error|Failed to create)"

# Bot server logs check karein
docker logs zoom-bot-server-api --tail 100
```

### Step 4: Verify Code Path

**Server 1 par:**

```bash
# Check if request is reaching bot server
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 5 "POST.*create"

# Check error handling
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 10 "catch (error)"
```

## Quick Test

**Server 1 par:**

```bash
# 1. Clear all logs
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 2. Watch logs
docker logs -f zoom-bot-server-api

# 3. In another terminal, test API
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 4. Check what appears in logs
# Should see:
# - "📥 Received request body" ✅
# - "📋 Extracted values" ✅
# - "Creating bots" ✅
# - "⏳ Executing setup script" ✅
# - "📋 Expected compose file: compose-8421085087-bots.yaml" ✅
```

## Expected Results

✅ **If request reaches bot server:**
- Logs me "📥 Received request body" dikhega
- Logs me "📋 Expected compose file: compose-8421085087-bots.yaml" dikhega
- NO `compose-50-bots.yaml` in logs

❌ **If request NOT reaching:**
- No logs at all
- Error from main API, not bot server
- Check main API logs


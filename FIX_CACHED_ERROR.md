# Fix Cached Error - compose-50-bots.yaml

## Problem
Request bheji hai, lekin logs nahi dikha rahe. Error me `compose-50-bots.yaml` dikha raha hai.

## Solution

### Step 1: Restart All Containers

**Server 1 par:**

```bash
# Restart bot server (clear any cached state)
docker restart zoom-bot-server-api

# Restart main API (clear any cached state)
docker restart zoom-dashboard-api

# Wait for containers to start
sleep 5

# Check containers are running
docker ps | grep -E "(zoom-bot-server-api|zoom-dashboard-api)"
```

### Step 2: Clear All Logs

**Server 1 par:**

```bash
# Clear all logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# Verify logs are cleared
docker logs zoom-bot-server-api --tail 5
# Should show only startup messages
```

### Step 3: Test with Real-time Logs

**Server 1 par:**

```bash
# Terminal 1 - Watch bot server logs
docker logs -f zoom-bot-server-api

# Terminal 2 - Watch main API logs
docker logs -f zoom-dashboard-api

# Terminal 3 - Create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Check Terminal 1 and 2 - dekho kya logs aate hain
```

### Step 4: Check Full Logs After Test

**Server 1 par:**

```bash
# Get ALL logs (no filter)
docker logs zoom-dashboard-api --tail 200
docker logs zoom-bot-server-api --tail 200
```

## Expected Results

✅ **After restart:**
- Bot server logs me "📥 Received request body" dikhega
- Main API logs me "📤 Sending request to bot server" dikhega
- Bot server logs me "📋 Expected compose file: compose-8421085087-bots.yaml" dikhega
- NO `compose-50-bots.yaml` in logs

❌ **If still failing:**
- Check if containers are on same network
- Check if bot server is accessible
- Check full logs for actual error


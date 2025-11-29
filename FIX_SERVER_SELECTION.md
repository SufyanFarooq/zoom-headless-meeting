# Fix Server Selection - Request Going to Server 2

## Problem
Request Server 2 par ja raha hai (`http://35.227.36.166:3001`) jabke Server 1 par space hai.

## Root Cause
Logs me old query dikha raha hai:
```
SELECT id, server_name, server_url, capacity, current_load 
FROM bot_servers 
WHERE status = 'active' 
AND (capacity - current_load) >= $1
ORDER BY current_load ASC, capacity DESC
LIMIT 1
```

Yeh query me `priority` column use nahi ho raha. Matlab container me old code cached hai.

## Solution

### Step 1: Rebuild Main API Container

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Pull latest code
git pull origin main

# 2. Verify code has priority logic
grep -n "priority = 1" api/services/botService.js
# Should show: priority = 1 query

# 3. Stop and remove main API container
docker stop zoom-dashboard-api
docker rm zoom-dashboard-api

# 4. Rebuild main API container (WITHOUT cache)
docker build --no-cache -f Dockerfile.api -t meetingsdk-headless-linux-sample-api .

# 5. Start container
docker compose -f docker-compose.full.yml up -d api

# 6. Check logs
docker logs zoom-dashboard-api --tail 20
```

### Step 2: Verify Server Selection

**Server 1 par:**

```bash
# Check database - verify priorities are set
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "
SELECT id, server_name, server_url, capacity, current_load, priority 
FROM bot_servers 
ORDER BY priority ASC;
"

# Should show:
# server-1: priority = 1, current_load = X
# server-2: priority = 2, current_load = Y
```

### Step 3: Test Server Selection

**Server 1 par:**

```bash
# Clear logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1

# Create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Check logs - dekho kya query execute ho raha hai
docker logs zoom-dashboard-api --tail 50 | grep -E "(Selected Server|Executed query|priority)"
```

## Expected Results

✅ **After rebuild:**
- Logs me "✅ Selected Server 1" dikhega (if Server 1 has space)
- Query me `priority = 1` dikhega
- Request Server 1 ko jayega: `http://bot-server:3001`

❌ **If still going to Server 2:**
- Check database priorities
- Check container has updated code
- Check logs for actual query


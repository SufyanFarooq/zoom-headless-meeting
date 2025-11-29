# Rebuild Main API Container - Fix Server Selection

## Problem
Logs me old query dikha raha hai (without priority), matlab container me old code cached hai.

## Solution

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

# 5. Start container using docker-compose
docker compose -f docker-compose.full.yml up -d api

# 6. Check logs
docker logs zoom-dashboard-api --tail 20

# 7. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 8. Check logs - dekho kya query execute ho raha hai
docker logs zoom-dashboard-api --tail 50 | grep -E "(Selected Server|priority|Executed query)"
```

## Expected Results

✅ **After rebuild:**
- Logs me "✅ Selected Server 1" dikhega (if Server 1 has space)
- Query me `priority = 1` dikhega
- Request Server 1 ko jayega: `http://bot-server:3001`
- NO request to Server 2

## Verify Database

**Server 1 par:**

```bash
# Check database priorities
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "
SELECT id, server_name, server_url, capacity, current_load, priority 
FROM bot_servers 
ORDER BY priority ASC;
"

# Should show:
# server-1: priority = 1, current_load = X
# server-2: priority = 2, current_load = Y
```


# Verify Container Code - Server 1

## Problem
Logs me "Selected Server" ya "priority" nahi dikha raha, matlab container me old code cached hai.

## Solution

**Server 1 par ye commands run karein:**

```bash
cd ~/zoom-headless-meeting

# 1. Verify code on server has priority logic
grep -n "priority = 1" api/services/botService.js
# Should show: 48:       AND priority = 1

# 2. Check what code is ACTUALLY running in container
docker exec zoom-dashboard-api grep -n "priority = 1" /app/api/services/botService.js
# If this shows nothing, container has old code!

# 3. Compare server code vs container code
echo "=== SERVER CODE ==="
grep -A 5 "priority = 1" api/services/botService.js | head -10

echo "=== CONTAINER CODE ==="
docker exec zoom-dashboard-api grep -A 5 "priority = 1" /app/api/services/botService.js | head -10

# 4. If container code is different, REBUILD:
docker stop zoom-dashboard-api
docker rm zoom-dashboard-api
docker build --no-cache -f Dockerfile.api -t meetingsdk-headless-linux-sample-api .
docker compose -f docker-compose.full.yml up -d api

# 5. Wait and verify again
sleep 5
docker exec zoom-dashboard-api grep -n "priority = 1" /app/api/services/botService.js
# Should show: 48:       AND priority = 1

# 6. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 7. Check FULL logs (not filtered)
docker logs zoom-dashboard-api --tail 100
# Look for: "✅ Selected Server 1" or "⚠️  Server 1 is full"
```

## Expected Results

✅ **After rebuild:**
- Container me code match karega server code se
- Logs me "✅ Selected Server 1" dikhega
- Query me `priority = 1` dikhega
- Request Server 1 ko jayega: `http://bot-server:3001`


# Load Balancing Test - Final Guide

## Current Setup
- ✅ Server 1: Capacity 150, Priority 1, Load 0
- ✅ Server 2: Capacity 50, Priority 2, Load 0
- ✅ Scripts installed on Server 2
- ✅ Bot server restarted

## Test Plan

### Test 1: Small Meeting (Server 1 use hoga)

**Create 10 bots meeting:**

```bash
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 10,
    "videoCount": 0,
    "audioCount": 10,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "timeoutSeconds": 7200
  }'
```

**Expected:** Server 1 use hoga (priority=1, capacity available)

**Verify:**
```bash
# Check Server 1 load
curl http://SERVER1_IP:3001/api/bots/capacity
# Expected: {"capacity":150,"currentLoad":10,"available":140}

# Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

---

### Test 2: Fill Server 1 (150 bots)

**Option A: Multiple Small Meetings**

```bash
# 15 meetings × 10 bots = 150 bots
for i in {1..15}; do
  curl -X POST http://SERVER1_IP:3000/api/meetings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -d "{
      \"meetingId\": \"5067498331\",
      \"password\": \"123456\",
      \"membersCount\": 10,
      \"videoCount\": 0,
      \"audioCount\": 10,
      \"nameType\": \"Indian\",
      \"meetingType\": \"Normal Member\"
    }"
  echo "Meeting $i created"
  sleep 2
done
```

**Option B: Large Meetings**

```bash
# 1 meeting × 100 bots + 1 meeting × 50 bots = 150 bots
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 100,
    "videoCount": 0,
    "audioCount": 100,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'

curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 50,
    "videoCount": 0,
    "audioCount": 50,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Monitor Progress:**
```bash
# Watch Server 1 load increase
watch -n 2 'curl -s http://SERVER1_IP:3001/api/bots/capacity | jq'
```

**Expected:** Server 1 load: 0 → 150

**Verify Server 1 Full:**
```bash
curl http://SERVER1_IP:3001/api/bots/capacity
# Expected: {"capacity":150,"currentLoad":150,"available":0}
```

---

### Test 3: Server 2 Auto-Use (Server 1 Full Hone Ke Baad)

**Jab Server 1 full ho jayega (150/150), nayi meeting automatically Server 2 par jayegi:**

```bash
# New meeting create karein (Server 1 full hai)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 10,
    "videoCount": 0,
    "audioCount": 10,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Expected:** Server 2 use hoga (Server 1 full hai)

**Verify:**
```bash
# Check Server 2 load increased
curl http://35.227.36.166:3001/api/bots/capacity
# Expected: {"capacity":50,"currentLoad":10,"available":40}

# Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

**Expected Output:**
```
 server_name | capacity | current_load | available | priority 
-------------+----------+--------------+-----------+----------
 server-1    |      150 |          150 |         0 |        1
 server-2    |       50 |           10 |        40 |        2
```

---

### Test 4: Fill Server 2 (50 bots)

```bash
# 4 more meetings × 10 bots = 40 bots (total 50)
for i in {1..4}; do
  curl -X POST http://SERVER1_IP:3000/api/meetings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -d '{
      "meetingId": "5067498331",
      "password": "123456",
      "membersCount": 10,
      "videoCount": 0,
      "audioCount": 10,
      "nameType": "Indian",
      "meetingType": "Normal Member"
    }'
  echo "Meeting $i created on Server 2"
  sleep 2
done
```

**Expected:** Server 2 load: 10 → 50

---

### Test 5: Both Servers Full (Should Fail)

```bash
# Try to create more bots (both servers full)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 10,
    "videoCount": 0,
    "audioCount": 10,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Expected Error:**
```json
{
  "error": "Failed to create meeting",
  "message": "No available bot server with sufficient capacity"
}
```

**Verify:**
```bash
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

**Expected:**
```
 server_name | capacity | current_load | available 
-------------+----------+--------------+-----------
 server-1    |      150 |          150 |         0
 server-2    |       50 |           50 |         0
```

---

## Monitoring Commands

### Real-time Monitoring

```bash
# Watch both servers
watch -n 2 '
echo "Server 1:"
curl -s http://SERVER1_IP:3001/api/bots/capacity | jq "."
echo ""
echo "Server 2:"
curl -s http://35.227.36.166:3001/api/bots/capacity | jq "."
'
```

### Check Running Containers

```bash
# Server 1 par
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}" | wc -l
# Expected: 150 containers

# Server 2 par
ssh user@35.227.36.166
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}" | wc -l
# Expected: 50 containers
```

### Check Database Status

```bash
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available, priority FROM bot_servers ORDER BY priority;"
```

---

## Quick Test Sequence

### Step-by-Step (Copy-Paste)

```bash
# 1. Small meeting (Server 1)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"5067498331","password":"123456","membersCount":10,"videoCount":0,"audioCount":10,"nameType":"Indian","meetingType":"Normal Member"}'

# 2. Check Server 1 load
curl http://SERVER1_IP:3001/api/bots/capacity

# 3. Fill Server 1 (create 14 more meetings × 10 bots = 140 more)
for i in {1..14}; do
  curl -X POST http://SERVER1_IP:3000/api/meetings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -d '{"meetingId":"5067498331","password":"123456","membersCount":10,"videoCount":0,"audioCount":10,"nameType":"Indian","meetingType":"Normal Member"}'
  sleep 1
done

# 4. Verify Server 1 full
curl http://SERVER1_IP:3001/api/bots/capacity
# Expected: {"capacity":150,"currentLoad":150,"available":0}

# 5. Create new meeting (Server 2 use hoga)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"5067498331","password":"123456","membersCount":10,"videoCount":0,"audioCount":10,"nameType":"Indian","meetingType":"Normal Member"}'

# 6. Verify Server 2 used
curl http://35.227.36.166:3001/api/bots/capacity
# Expected: {"capacity":50,"currentLoad":10,"available":40}

# 7. Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load FROM bot_servers ORDER BY priority;"
```

---

## Expected Results Summary

| Test | Bots Created | Server Used | Server 1 Load | Server 2 Load |
|------|--------------|-------------|---------------|----------------|
| Test 1 | 10 | Server 1 | 10/150 | 0/50 |
| Test 2 | 150 | Server 1 | 150/150 (Full) | 0/50 |
| Test 3 | 10 | Server 2 | 150/150 (Full) | 10/50 |
| Test 4 | 50 | Server 2 | 150/150 (Full) | 50/50 (Full) |
| Test 5 | 10 | ❌ Error | 150/150 (Full) | 50/50 (Full) |

---

## Summary

**Current Setup:**
- ✅ Server 1: 150 capacity (Priority 1)
- ✅ Server 2: 50 capacity (Priority 2)
- ✅ Scripts installed
- ✅ Ready to test

**Test Flow:**
1. ✅ Create meetings → Server 1 use hoga (0 → 150)
2. ✅ Server 1 full → New meetings Server 2 par jayengi (0 → 50)
3. ✅ Both full → New requests fail

**Load Balancing:**
- Server 1 pehle use hota hai (priority=1)
- Server 1 full hone par Server 2 use hota hai (priority=2)
- Dono full hone par error aata hai

Ab test karein! 🚀


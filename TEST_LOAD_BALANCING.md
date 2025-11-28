# Load Balancing Test Guide - Step by Step

## Current Setup
- Server 1: Capacity 200, Priority 1 (Primary)
- Server 2: Capacity 50, Priority 2 (Secondary)
- **Goal**: Test karein ki load balancing kaise kaam karta hai

## Test Plan

### Phase 1: Server 1 Test (0 → 200 bots)

### Step 1: Small Meeting Create Karein (Server 1 use hoga)

```bash
# 10 bots - Server 1 use hoga
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

**Expected:** Server 1 use hoga
**Verify:**
```bash
# Check Server 1 load
curl http://SERVER1_IP:3001/api/bots/capacity

# Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

### Step 2: Server 1 Ko Fill Karein (200 bots tak)

**Option A: Multiple Small Meetings**

```bash
# 20 meetings × 10 bots = 200 bots
for i in {1..20}; do
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
# 2 meetings × 100 bots = 200 bots
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
    "membersCount": 100,
    "videoCount": 0,
    "audioCount": 100,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Monitor Progress:**
```bash
# Watch Server 1 load increase
watch -n 2 'curl -s http://SERVER1_IP:3001/api/bots/capacity | jq'
```

**Expected:** Server 1 load: 0 → 200

### Step 3: Verify Server 1 Full Hai

```bash
# Check Server 1 is full
curl http://SERVER1_IP:3001/api/bots/capacity

# Expected:
# {
#   "capacity": 200,
#   "currentLoad": 200,
#   "available": 0
# }
```

---

### Phase 2: Server 2 Test (Server 1 Full Hone Ke Baad)

### Step 4: New Meeting Create Karein (Server 2 use hoga)

Jab Server 1 full ho jayega (200/200), nayi meeting automatically Server 2 par jayegi:

```bash
# 10 bots - Server 2 use hoga (Server 1 full hai)
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

# Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

**Expected Output:**
```
 server_name | capacity | current_load | available | priority 
-------------+----------+--------------+-----------+----------
 server-1    |      200 |          200 |         0 |        1
 server-2    |       50 |           10 |        40 |        2
```

### Step 5: Server 2 Ko Fill Karein (50 bots tak)

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

### Phase 3: Both Servers Full Test

### Step 6: Try to Create More Bots (Should Fail)

```bash
# Try 10 more bots (both servers full)
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
# Both servers full
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
```

**Expected:**
```
 server_name | capacity | current_load | available 
-------------+----------+--------------+-----------
 server-1    |      200 |          200 |         0
 server-2    |       50 |           50 |         0
```

---

## Complete Test Script

### Automated Test Script

```bash
#!/bin/bash
# test-load-balancing.sh

SERVER1_IP="YOUR_SERVER1_IP"
AUTH_TOKEN="YOUR_TOKEN"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Load Balancing Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Phase 1: Fill Server 1
echo "Phase 1: Filling Server 1 (0 → 200 bots)..."
for i in {1..20}; do
  echo "Creating meeting $i/20..."
  curl -s -X POST "http://${SERVER1_IP}:3000/api/meetings" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -d "{
      \"meetingId\": \"5067498331\",
      \"password\": \"123456\",
      \"membersCount\": 10,
      \"videoCount\": 0,
      \"audioCount\": 10,
      \"nameType\": \"Indian\",
      \"meetingType\": \"Normal Member\"
    }" > /dev/null
  sleep 1
done

echo "✅ Server 1 filled"
echo ""

# Check Server 1 status
echo "Server 1 Status:"
curl -s "http://${SERVER1_IP}:3001/api/bots/capacity" | jq '.'
echo ""

# Phase 2: Test Server 2
echo "Phase 2: Testing Server 2 (Server 1 full)..."
echo "Creating meeting on Server 2..."
curl -X POST "http://${SERVER1_IP}:3000/api/meetings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 10,
    "videoCount": 0,
    "audioCount": 10,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'

echo ""
echo "✅ Test complete!"
echo ""

# Final status
echo "Final Status:"
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers ORDER BY priority;"
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

### Check Running Bots

```bash
# Server 1 par
ssh user@SERVER1_IP
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}" | wc -l

# Server 2 par
ssh user@35.227.36.166
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}" | wc -l
```

---

## Expected Results

### After Phase 1 (Server 1 Full):
- Server 1: 200/200 bots ✅
- Server 2: 0/50 bots ✅

### After Phase 2 (Server 2 Used):
- Server 1: 200/200 bots ✅
- Server 2: 10/50 bots ✅

### After Phase 3 (Both Full):
- Server 1: 200/200 bots ✅
- Server 2: 50/50 bots ✅
- New requests: ❌ Error (no capacity)

---

## Summary

**Test Flow:**
1. ✅ Create meetings → Server 1 use hoga (0 → 200)
2. ✅ Server 1 full → New meetings Server 2 par jayengi (0 → 50)
3. ✅ Both full → New requests fail

**Key Points:**
- Server 1 pehle use hota hai (priority=1)
- Server 1 full hone par Server 2 use hota hai (priority=2)
- Dono full hone par error aata hai

Ye steps follow karein, load balancing test ho jayega! 🚀


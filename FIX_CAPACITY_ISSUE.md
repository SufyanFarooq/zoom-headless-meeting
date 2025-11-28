# Fix Capacity Issue - 210 Bots Request

## Problem

Request: 210 bots create karna hai
- Server 1 capacity: 200 bots
- Server 2 capacity: 50 bots
- **Issue**: Koi bhi server individually 210 bots handle nahi kar sakta

## Solutions

### Solution 1: Increase Server Capacities (Recommended)

#### Option A: Increase Server 1 Capacity

```sql
-- Database me connect
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

-- Server 1 capacity badha dein (200 → 250)
UPDATE bot_servers SET capacity = 250 WHERE server_name = 'server-1';

-- Verify
SELECT server_name, capacity, current_load, priority FROM bot_servers;
\q
```

**After this:** 210 bots Server 1 par create ho jayenge.

#### Option B: Increase Both Servers

```sql
-- Server 1: 200 → 250
UPDATE bot_servers SET capacity = 250 WHERE server_name = 'server-1';

-- Server 2: 50 → 100
UPDATE bot_servers SET capacity = 100 WHERE server_name = 'server-2';

-- Verify
SELECT server_name, capacity, current_load, priority FROM bot_servers;
```

### Solution 2: Split Meeting (If Can't Increase Capacity)

Agar capacity badha nahi sakte, to meeting ko split karein:

**Instead of:** 1 meeting with 210 bots
**Do:** 2 meetings with 105 bots each

```bash
# Meeting 1: 105 bots
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 105,
    "videoCount": 0,
    "audioCount": 105,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'

# Meeting 2: 105 bots
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 105,
    "videoCount": 0,
    "audioCount": 105,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

### Solution 3: Update Capacity Based on Server Resources

**Server 1 (32 vCPUs, 128GB):**
- CPU: 32 / 0.3 = ~106 bots per CPU
- Memory: 128GB / 256MB = ~512 bots
- **Recommended**: 250-300 bots (CPU-limited, safe)

**Server 2 (4 vCPUs, 16GB):**
- CPU: 4 / 0.3 = ~13 bots per CPU
- Memory: 16GB / 256MB = ~64 bots
- **Recommended**: 50-60 bots (CPU-limited, safe)

## Quick Fix Commands

### Increase Server 1 Capacity to 250

```bash
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "UPDATE bot_servers SET capacity = 250 WHERE server_name = 'server-1';"

# Verify
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, priority FROM bot_servers ORDER BY priority;"
```

### Increase Both Servers

```bash
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots << EOF
UPDATE bot_servers SET capacity = 250 WHERE server_name = 'server-1';
UPDATE bot_servers SET capacity = 100 WHERE server_name = 'server-2';
SELECT server_name, capacity, current_load, priority FROM bot_servers ORDER BY priority;
EOF
```

## Test After Fix

```bash
# Retry meeting creation
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 210,
    "videoCount": 0,
    "audioCount": 210,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "timeoutSeconds": 7200
  }'
```

**Expected:** Success! Server 1 use hoga (capacity 250 > 210)

## Recommended Capacities

Based on server specs:

| Server | vCPUs | Memory | Recommended Capacity |
|--------|-------|--------|---------------------|
| Server 1 | 32 | 128GB | 250-300 bots |
| Server 2 | 4 | 16GB | 50-100 bots |

**Current Setup:**
- Server 1: 200 → **250** (recommended)
- Server 2: 50 → **100** (optional, for future)

## Summary

**Problem:** 210 bots > Server 1 capacity (200)
**Solution:** Server 1 capacity badha dein: 200 → 250
**Command:**
```sql
UPDATE bot_servers SET capacity = 250 WHERE server_name = 'server-1';
```

**After fix:** 210 bots successfully create ho jayenge! ✅


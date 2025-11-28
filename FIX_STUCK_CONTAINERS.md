# Fix Stuck Containers - Server 1

## Problem
- 200 bots create kiye the
- Dashboard se stop kiya
- Lekin abhi bhi 42 containers running hain
- Containers stop nahi ho rahe

## Quick Fix Commands

### Option 1: Stop All Containers (Quick)

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# All bot containers stop karein
docker stop $(docker ps --filter "name=zoom-bot" -q)

# Verify
docker ps | grep zoom-bot
# Should show 0 containers
```

### Option 2: Force Stop (If Normal Stop Fails)

```bash
# Force kill all bot containers
docker kill $(docker ps --filter "name=zoom-bot" -q)

# Verify
docker ps | grep zoom-bot
```

### Option 3: Using Script (Complete Fix)

```bash
# Server 1 par
cd /opt/zoom-headless-meeting
chmod +x scripts/fix-stuck-containers.sh
./scripts/fix-stuck-containers.sh
```

## Update Database Load

**Containers stop karne ke baad database update karein:**

```bash
# Database me connect
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Server load reset karein
UPDATE bot_servers SET current_load = 0 WHERE server_name = 'server-1';

# Verify
SELECT server_name, capacity, current_load FROM bot_servers;
\q
```

## Complete Fix Sequence

```bash
# Step 1: Stop all containers
docker stop $(docker ps --filter "name=zoom-bot" -q) 2>/dev/null || true

# Step 2: Force kill if still running
docker kill $(docker ps --filter "name=zoom-bot" -q) 2>/dev/null || true

# Step 3: Verify
docker ps | grep zoom-bot
# Should be empty

# Step 4: Update database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "UPDATE bot_servers SET current_load = 0 WHERE server_name = 'server-1';"

# Step 5: Verify database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load FROM bot_servers;"
```

## Check Current Status

```bash
# Running containers count
docker ps --filter "name=zoom-bot" --format "{{.Names}}" | wc -l

# List running containers
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"

# Database load
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load FROM bot_servers;"
```

## Why Containers Didn't Stop?

**Possible Reasons:**
1. **Timeout**: Stop request timeout ho gaya
2. **Container IDs missing**: Database me container_ids empty ho gaye
3. **Network issue**: Bot server API unreachable
4. **Container stuck**: Containers hang ho gaye

**Solution:** Manual cleanup (commands above)

## Prevent Future Issues

### Option 1: Increase Stop Timeout

Already implemented in code, but verify:

```javascript
// api/services/botService.js
const timeoutMs = Math.min(Math.max(batches * 2000 + 30000, 60000), 600000);
```

### Option 2: Add Cleanup Cron Job

```bash
# Daily cleanup of stopped containers
0 2 * * * docker rm $(docker ps -a --filter "name=zoom-bot" --filter "status=exited" -q) 2>/dev/null || true
```

### Option 3: Monitor Container Health

```bash
# Check for stuck containers
docker ps --filter "name=zoom-bot" --format "{{.Names}}\t{{.Status}}" | grep -v "Up"
```

## Summary

**Current:** 42 containers stuck running  
**Fix:** Manual stop + Database update  
**Commands:**
```bash
docker stop $(docker ps --filter "name=zoom-bot" -q)
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c "UPDATE bot_servers SET current_load = 0 WHERE server_name = 'server-1';"
```

Ye commands run karein, containers stop ho jayenge! ✅


# Server 2 Registration - Next Steps

## ✅ Current Status
- ✅ Server 2 bot server running
- ✅ Health check working: `http://localhost:3001/health`
- ✅ Container: `zoom-bot-server-api` started

## Step 1: Register Server 2 on Server 1

Server 2 ko Server 1 ke database me register karna hai taake load balancing kaam kare.

### Option A: Using API (Recommended)

**Server 1 ka IP address chahiye.** Agar Server 1 ka IP hai `SERVER1_IP`, to:

```bash
# Server 2 par ya kisi bhi machine se
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://35.227.36.166:3001",
    "capacity": 10,
    "priority": 2
  }'
```

**Agar authentication token chahiye:**
1. Server 1 par login karein
2. Dashboard se token lein
3. Ya database se directly register karein (Option B)

### Option B: Direct Database (If API token nahi hai)

**Server 1 par database me directly insert karein:**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# Database me connect karein
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Register Server 2
INSERT INTO bot_servers (server_name, server_url, capacity, priority, status)
VALUES ('server-2', 'http://35.227.36.166:3001', 10, 2, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
  server_url = EXCLUDED.server_url,
  capacity = EXCLUDED.capacity,
  priority = EXCLUDED.priority,
  status = 'active',
  last_heartbeat = NOW();

# Verify
SELECT id, server_name, server_url, capacity, current_load, priority, status 
FROM bot_servers 
ORDER BY priority;

# Exit
\q
```

### Option C: Using Setup Script

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting
./scripts/setup-load-balancing.sh
```

Ya manually:

```bash
./scripts/register-servers.sh
```

## Step 2: Verify Registration

### Check Server 2 is Registered

```bash
# Server 1 par API se check karein
curl http://SERVER1_IP:3000/api/bot-servers \
  -H "Authorization: Bearer YOUR_TOKEN"

# Expected output:
# {
#   "success": true,
#   "servers": [
#     {
#       "id": 1,
#       "server_name": "server-1",
#       "server_url": "http://SERVER1_IP:3001",
#       "capacity": 100,
#       "current_load": 0,
#       "priority": 1,
#       "status": "active"
#     },
#     {
#       "id": 2,
#       "server_name": "server-2",
#       "server_url": "http://35.227.36.166:3001",
#       "capacity": 10,
#       "current_load": 0,
#       "priority": 2,
#       "status": "active"
#     }
#   ]
# }
```

## Step 3: Test Load Balancing

### Test 1: Small Meeting (Server 1 use hoga)

```bash
# Server 1 par ya Dashboard se
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "123456789",
    "password": "test123",
    "membersCount": 10,
    "videoCount": 5,
    "audioCount": 5,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "timeoutSeconds": 3600
  }'
```

**Expected:** Server 1 use hoga (priority=1, capacity available)

### Test 2: Fill Server 1 (100+ bots)

```bash
# Multiple meetings create karein taake Server 1 full ho jaye
# Example: 10 meetings with 10 bots each = 100 bots
```

### Test 3: New Meeting (Server 2 use hoga)

Jab Server 1 full ho jayega, nayi meeting automatically Server 2 par jayegi:

```bash
# New meeting create karein
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "987654321",
    "password": "test456",
    "membersCount": 10,
    "videoCount": 5,
    "audioCount": 5,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Expected:** Server 2 use hoga (Server 1 full hai)

## Step 4: Monitor Load Balancing

### Check Server Loads

```bash
# Server 1 load
curl http://SERVER1_IP:3001/api/bots/capacity

# Server 2 load
curl http://35.227.36.166:3001/api/bots/capacity

# Database me check
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers;"
```

### Check Running Bots

```bash
# Server 1 par
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}"

# Server 2 par
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}"
```

## Step 5: Firewall Rules (Important!)

### GCP Firewall me Port 3001 Allow Karein

**GCP Console se:**
1. Go to **VPC Network → Firewall**
2. Click **"Create Firewall Rule"**
3. Name: `allow-bot-server`
4. Targets: `All instances in the network`
5. Source IP ranges: `0.0.0.0/0` (ya specific Server 1 IP)
6. Protocols and ports: `tcp:3001`
7. Click **"Create"**

**Ya gcloud CLI se:**
```bash
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

## Step 6: Verify End-to-End

### Complete Test Flow

1. **Server 2 health check:**
   ```bash
   curl http://35.227.36.166:3001/health
   ```

2. **Server 2 capacity:**
   ```bash
   curl http://35.227.36.166:3001/api/bots/capacity
   ```

3. **Create test meeting:**
   - Dashboard se ya API se meeting create karein
   - Check logs: Server 1 ya Server 2 use hoga

4. **Check bot containers:**
   ```bash
   # Server 1 par
   docker ps | grep zoom-bot
   
   # Server 2 par
   docker ps | grep zoom-bot
   ```

## Troubleshooting

### Server 2 Not Receiving Requests?

1. **Check registration:**
   ```bash
   curl http://SERVER1_IP:3000/api/bot-servers
   ```

2. **Check Server 2 URL accessible:**
   ```bash
   # Server 1 se test karein
   curl http://35.227.36.166:3001/health
   ```

3. **Check firewall:**
   - GCP firewall me port 3001 allow hai?

4. **Check priority:**
   - Server 1 priority = 1
   - Server 2 priority = 2

### Server 2 Not Responding?

```bash
# Check container logs
docker logs zoom-bot-server-api

# Check container status
docker ps -a | grep zoom-bot-server

# Restart if needed
cd /opt/zoom-headless-meeting
docker compose -f docker-compose.bot-server.yml restart
```

## Summary - Next Steps Checklist

- [ ] **Step 1:** Register Server 2 on Server 1 (API ya Database)
- [ ] **Step 2:** Verify registration (check servers list)
- [ ] **Step 3:** Test load balancing (small meeting → Server 1)
- [ ] **Step 4:** Fill Server 1 (100+ bots)
- [ ] **Step 5:** Test Server 2 (new meeting → Server 2)
- [ ] **Step 6:** Setup firewall (GCP port 3001)
- [ ] **Step 7:** Monitor both servers

## Quick Commands Reference

```bash
# Register Server 2
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{"serverName": "server-2", "serverUrl": "http://35.227.36.166:3001", "capacity": 10, "priority": 2}'

# Check servers
curl http://SERVER1_IP:3000/api/bot-servers

# Test Server 2
curl http://35.227.36.166:3001/health
curl http://35.227.36.166:3001/api/bots/capacity

# Check firewall
gcloud compute firewall-rules list --filter="name~bot-server"
```

---

**Current Status:**
- ✅ Server 2 running
- ✅ Health check OK
- ⏭️ Next: Register on Server 1


# Next Steps After Server Registration

## ✅ Current Status
- ✅ Server 1: Registered (capacity: 200, priority: 1)
- ✅ Server 2: Registered (capacity: 50, priority: 2)
- ✅ Priority column added
- ✅ Load balancing configured

## Step 1: Firewall Rules (Important!)

### GCP Server 2 par Port 3001 Allow Karein

**GCP Console se:**
1. Go to **VPC Network → Firewall**
2. Click **"Create Firewall Rule"**
3. Name: `allow-bot-server`
4. Targets: `All instances in the network`
5. Source IP ranges: `0.0.0.0/0` (ya Server 1 ka specific IP)
6. Protocols and ports: `tcp:3001`
7. Click **"Create"**

**Ya gcloud CLI se:**
```bash
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

### Verify Firewall
```bash
# Check if rule exists
gcloud compute firewall-rules list --filter="name~bot-server"

# Test connectivity from Server 1
curl http://35.227.36.166:3001/health
```

## Step 2: Test Load Balancing

### Test 1: Small Meeting (Server 1 use hoga)

```bash
# Dashboard se ya API se
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

**Verify:**
```bash
# Check Server 1 load
curl http://SERVER1_IP:3001/api/bots/capacity

# Check database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, (capacity - current_load) as available FROM bot_servers;"
```

### Test 2: Fill Server 1 (200+ bots)

**Option A: Multiple Small Meetings**
```bash
# 20 meetings with 10 bots each = 200 bots
for i in {1..20}; do
  curl -X POST http://SERVER1_IP:3000/api/meetings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -d "{
      \"meetingId\": \"12345678$i\",
      \"password\": \"test123\",
      \"membersCount\": 10,
      \"videoCount\": 5,
      \"audioCount\": 5,
      \"nameType\": \"Indian\",
      \"meetingType\": \"Normal Member\"
    }"
  sleep 2
done
```

**Option B: Large Meeting**
```bash
# 1 meeting with 200 bots
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "999999999",
    "password": "test123",
    "membersCount": 200,
    "videoCount": 100,
    "audioCount": 100,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Monitor Server 1 Load:**
```bash
# Watch Server 1 load increase
watch -n 2 'curl -s http://SERVER1_IP:3001/api/bots/capacity | jq'
```

### Test 3: Server 2 Auto-Use (When Server 1 Full)

Jab Server 1 ka `current_load >= 200` ho jayega, nayi meeting automatically Server 2 par jayegi:

```bash
# New meeting create karein (Server 1 full hai)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "111111111",
    "password": "test456",
    "membersCount": 10,
    "videoCount": 5,
    "audioCount": 5,
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
  "SELECT server_name, capacity, current_load FROM bot_servers ORDER BY priority;"
```

## Step 3: Monitor Both Servers

### Real-time Monitoring Script

```bash
# Create monitoring script
cat > monitor-servers.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Server Load Monitoring"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Server 1:"
  curl -s http://SERVER1_IP:3001/api/bots/capacity | jq '.'
  echo ""
  
  echo "Server 2:"
  curl -s http://35.227.36.166:3001/api/bots/capacity | jq '.'
  echo ""
  
  echo "Database Status:"
  docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
    "SELECT server_name, capacity, current_load, (capacity - current_load) as available, priority FROM bot_servers ORDER BY priority;" 2>/dev/null
  
  echo ""
  echo "Press Ctrl+C to stop"
  sleep 5
done
EOF

chmod +x monitor-servers.sh
./monitor-servers.sh
```

### Check Running Bots

```bash
# Server 1 par
ssh user@SERVER1_IP
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

# Server 2 par
ssh user@35.227.36.166
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
```

## Step 4: Verify Load Balancing Logic

### Check Server Selection

API logs me check karein ki kaunsa server select ho raha hai:

```bash
# Server 1 API logs
docker logs zoom-dashboard-api -f | grep "Selected Server"
```

Expected logs:
```
✅ Selected Server 1 (server-1) - Load: 0/200
⚠️  Server 1 is full, trying Server 2...
✅ Selected Server 2 (server-2) - Load: 0/50
```

## Step 5: Capacity Management

### Current Configuration
- **Server 1**: 200 bots capacity (Primary)
- **Server 2**: 50 bots capacity (Secondary)
- **Total**: 250 bots capacity

### Update Capacity (if needed)

```sql
-- Database me connect
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

-- Update Server 1 capacity
UPDATE bot_servers SET capacity = 200 WHERE server_name = 'server-1';

-- Update Server 2 capacity
UPDATE bot_servers SET capacity = 50 WHERE server_name = 'server-2';

-- Verify
SELECT server_name, capacity, current_load FROM bot_servers;
\q
```

## Step 6: Production Checklist

- [ ] ✅ Firewall rules configured (port 3001)
- [ ] ✅ Server 1 registered (priority=1, capacity=200)
- [ ] ✅ Server 2 registered (priority=2, capacity=50)
- [ ] ✅ Load balancing tested (Server 1 → Server 2)
- [ ] ✅ Monitoring setup
- [ ] ✅ Health checks working
- [ ] ✅ Logs accessible

## Step 7: Dashboard Verification

### Check Dashboard

1. Open Dashboard: `http://SERVER1_IP:8080`
2. Login karein
3. Create meeting test karein
4. Check meeting details me `bot_server_id` verify karein

### API Endpoints Test

```bash
# List all servers
curl http://SERVER1_IP:3000/api/bot-servers \
  -H "Authorization: Bearer YOUR_TOKEN"

# List active meetings
curl http://SERVER1_IP:3000/api/meetings?status=active \
  -H "Authorization: Bearer YOUR_TOKEN"

# Check usage
curl http://SERVER1_IP:3000/api/usage \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Troubleshooting

### Server 2 Not Receiving Requests?

1. **Check Server 1 load:**
   ```bash
   curl http://SERVER1_IP:3001/api/bots/capacity
   ```
   Agar `currentLoad < 200`, to Server 1 use hoga.

2. **Check firewall:**
   ```bash
   # Server 1 se test
   curl http://35.227.36.166:3001/health
   ```

3. **Check logs:**
   ```bash
   docker logs zoom-dashboard-api | grep "selectBestServer"
   ```

### Load Not Updating?

```sql
-- Manual update (if needed)
UPDATE bot_servers 
SET current_load = (
  SELECT COUNT(*) 
  FROM meetings 
  WHERE bot_server_id = bot_servers.id 
  AND status = 'active'
);
```

## Summary

**Current Setup:**
- ✅ Server 1: 200 bots (Primary)
- ✅ Server 2: 50 bots (Secondary)
- ✅ Load balancing: Automatic

**Next Actions:**
1. ✅ Firewall configure karein
2. ✅ Load balancing test karein
3. ✅ Monitoring setup karein
4. ✅ Production use karein

**Load Balancing Flow:**
1. Request aata hai → Server 1 check hota hai
2. Agar Server 1 me capacity hai → Server 1 use hota hai
3. Agar Server 1 full hai → Server 2 use hota hai
4. Agar dono full hain → Error

Sab ready hai! Ab test karein aur production me use karein. 🚀


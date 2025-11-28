# Verify Firewall Rule - Already Created!

## ✅ Good News!

Firewall rule **already created** hai! Image me dikh raha hai:
- **Name**: `allow-bot-server`
- **Type**: Ingress
- **Targets**: Apply to all
- **IP ranges**: `0.0.0.0/0`
- **Protocols / ports**: `tcp:3001`
- **Action**: Allow

## Step 1: Test Connectivity

### From Server 1 (or any machine):

```bash
# Test Server 2 health endpoint
curl http://35.227.36.166:3001/health

# Expected output:
# {"status":"ok","timestamp":"2025-11-28T..."}
```

### From Server 2 itself:

```bash
# Local test
curl http://localhost:3001/health

# External IP test
curl http://35.227.36.166:3001/health
```

## Step 2: Test from Server 1

**Server 1 par SSH karke:**

```bash
# Server 1 se Server 2 test karein
curl http://35.227.36.166:3001/health

# Capacity check
curl http://35.227.36.166:3001/api/bots/capacity
```

**Expected:**
```json
{
  "success": true,
  "capacity": 50,
  "currentLoad": 0,
  "available": 50
}
```

## Step 3: Verify Load Balancing Works

### Create Test Meeting

```bash
# Server 1 API se meeting create karein
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
    "meetingType": "Normal Member"
  }'
```

**Check logs:**
- Server 1 use hoga (priority=1, capacity available)
- Agar Server 1 full hai, Server 2 use hoga

## Step 4: Check Firewall Rule Details (Optional)

Agar gcloud authentication fix karna hai:

### Fix Service Account Permissions

**Option A: Use User Account (Recommended)**

```bash
# Logout from service account
gcloud auth revoke 175344422655-compute@developer.gserviceaccount.com

# Login with your user account
gcloud auth login

# Set project
gcloud config set project responsive-sun-466212-a2

# Now firewall commands will work
gcloud compute firewall-rules list --filter="name~bot-server"
```

**Option B: Grant Permissions to Service Account**

GCP Console se:
1. Go to **IAM & Admin → IAM**
2. Find service account: `175344422655-compute@developer.gserviceaccount.com`
3. Click **Edit**
4. Add role: **Compute Security Admin** (ya **Owner**)
5. Save

## Step 5: Complete Test

### End-to-End Test

```bash
# 1. Server 2 health check
curl http://35.227.36.166:3001/health

# 2. Server 2 capacity
curl http://35.227.36.166:3001/api/bots/capacity

# 3. Create meeting (will use Server 1 first)
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "999999999",
    "password": "test123",
    "membersCount": 10,
    "videoCount": 5,
    "audioCount": 5,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'

# 4. Check which server was used
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT id, meeting_id, bot_server_id, members_count FROM meetings ORDER BY id DESC LIMIT 1;"

# 5. Check server loads
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
  "SELECT server_name, capacity, current_load, priority FROM bot_servers ORDER BY priority;"
```

## Troubleshooting

### Still Can't Connect?

1. **Check firewall rule is enabled:**
   - GCP Console → Firewall Rules
   - `allow-bot-server` ka status **Enabled** hona chahiye

2. **Check VM network tags:**
   - VM instance → Edit → Network tags
   - Agar firewall rule me target tags hain, to VM ko same tags chahiye

3. **Check Server 2 is running:**
   ```bash
   # On Server 2
   docker ps | grep zoom-bot-server
   curl http://localhost:3001/health
   ```

4. **Check Server 2 external IP:**
   ```bash
   # Verify IP is correct
   curl -I http://35.227.36.166:3001/health
   ```

### Authentication Issue (Optional Fix)

Agar gcloud commands use karni hain:

```bash
# Use user account instead of service account
gcloud auth login
gcloud config set account YOUR_EMAIL@gmail.com
gcloud config set project responsive-sun-466212-a2

# Now commands will work
gcloud compute firewall-rules describe allow-bot-server
```

## Summary

**Current Status:**
- ✅ Firewall rule created: `allow-bot-server`
- ✅ Port 3001 allowed
- ✅ Source: 0.0.0.0/0 (all IPs)
- ✅ Action: Allow

**Next Steps:**
1. ✅ Test connectivity: `curl http://35.227.36.166:3001/health`
2. ✅ Test load balancing: Create meeting
3. ✅ Monitor servers: Check loads

**Firewall rule already hai!** Ab bas test karein aur use karein. 🚀


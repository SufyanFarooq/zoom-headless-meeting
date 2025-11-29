# Check Bot Server URL Configuration

## Problem
Main API (port 3000) se bot server (port 3001) ko call kar rahe hain, lekin logs nahi aa rahe.

## Debug Steps

### Step 1: Check Database Bot Server URL

**Server 1 par:**

```bash
# Check bot server URL in database
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "SELECT id, server_name, server_url, capacity, current_load, priority FROM bot_servers;"

# Should see:
# server_url should be: http://bot-server:3001 (for Docker) or http://localhost:3001 (for non-Docker)
```

### Step 2: Check Main API Logs

**Server 1 par:**

```bash
# Check main API logs for bot server call
docker logs zoom-dashboard-api --tail 100 | grep -E "(Sending request to bot server|bot server|Bot server error)"

# Look for:
# - "📤 Sending request to bot server"
# - "🔧 Fixed bot server URL"
# - "Bot server error"
```

### Step 3: Check Bot Server Logs

**Server 1 par:**

```bash
# Check if request reaches bot server
docker logs zoom-bot-server-api --tail 100

# Look for:
# - "📥 Received request body"
# - "📋 Extracted values"
# - "Creating bots"
```

### Step 4: Test Direct Bot Server Call

**Server 1 par:**

```bash
# Test bot server directly (from inside Docker network)
docker exec zoom-dashboard-api curl -X POST http://bot-server:3001/api/bots/create \
  -H "Content-Type: application/json" \
  -d '{
    "meetingId":"8421085087",
    "password":"123456",
    "joinUrl":"https://zoom.us/j/8421085087?pwd=123456",
    "videoCount":0,
    "audioCount":20,
    "nameType":"Indian",
    "meetingType":"Normal Member",
    "accountId":"kOjrXedBRwGlbGiCyzQOyQ",
    "clientId":"9bk9CyXgSgqggGe5InpVMA",
    "clientSecret":"OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
  }'

# Check bot server logs
docker logs zoom-bot-server-api --tail 50
```

### Step 5: Check Network Connectivity

**Server 1 par:**

```bash
# Check if containers can communicate
docker exec zoom-dashboard-api ping -c 2 bot-server

# Check if bot server is accessible
docker exec zoom-dashboard-api curl http://bot-server:3001/health
```

## Fix Steps

### If URL is Wrong

**Server 1 par:**

```bash
# Update bot server URL in database
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "
UPDATE bot_servers 
SET server_url = 'http://bot-server:3001' 
WHERE server_name = 'server-1';
"

# Verify
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "SELECT server_name, server_url FROM bot_servers;"
```

### If Network Issue

**Server 1 par:**

```bash
# Check if containers are on same network
docker network inspect meetingsdk-headless-linux-sample_zoom-network | grep -A 5 "Containers"

# Should see both:
# - zoom-dashboard-api
# - zoom-bot-server-api
```

## Expected Results

✅ **Success:**
- Database me `server_url = 'http://bot-server:3001'` (Docker) ya `http://localhost:3001` (non-Docker)
- Main API logs me "📤 Sending request to bot server: http://bot-server:3001/api/bots/create"
- Bot server logs me "📥 Received request body"
- Bot server logs me "📋 Expected compose file: compose-8421085087-bots.yaml"

❌ **Failure:**
- Agar logs nahi aa rahe, to network issue hai
- Agar wrong URL, to database update karein


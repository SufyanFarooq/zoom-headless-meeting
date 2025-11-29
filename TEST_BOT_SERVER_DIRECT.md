# Test Bot Server Direct Call

## Problem
Container me curl nahi hai, direct call test nahi kar sakte.

## Alternative Test Methods

### Method 1: Check Logs After API Call

**Server 1 par:**

```bash
# 1. Clear bot server logs
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 2. Watch logs in real-time
docker logs -f zoom-bot-server-api

# 3. In another terminal, create meeting via main API
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 4. Check Terminal 1 - dekho kya logs aate hain
```

### Method 2: Use Node to Test

**Server 1 par:**

```bash
# Create test script in main API container
docker exec zoom-dashboard-api node -e "
const axios = require('axios');
axios.post('http://bot-server:3001/api/bots/create', {
  meetingId: '8421085087',
  password: '123456',
  joinUrl: 'https://zoom.us/j/8421085087?pwd=123456',
  videoCount: 0,
  audioCount: 20,
  nameType: 'Indian',
  meetingType: 'Normal Member',
  accountId: 'kOjrXedBRwGlbGiCyzQOyQ',
  clientId: '9bk9CyXgSgqggGe5InpVMA',
  clientSecret: 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'
}).then(r => console.log('Success:', JSON.stringify(r.data))).catch(e => console.error('Error:', e.message));
"

# Check bot server logs
docker logs zoom-bot-server-api --tail 100
```

### Method 3: Check Network Connectivity

**Server 1 par:**

```bash
# Check if containers can communicate
docker exec zoom-dashboard-api ping -c 2 bot-server

# Check if bot server is accessible
docker exec zoom-dashboard-api wget -q -O- http://bot-server:3001/health || echo "wget not available"

# Or use node
docker exec zoom-dashboard-api node -e "require('http').get('http://bot-server:3001/health', (r) => {let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))}).on('error',e=>console.error(e));"
```

### Method 4: Check Main API Logs

**Server 1 par:**

```bash
# Clear main API logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1

# Watch main API logs
docker logs -f zoom-dashboard-api

# In another terminal, create meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Check Terminal 1 - dekho:
# - "📤 Sending request to bot server"
# - "🔧 Fixed bot server URL"
# - Error messages
```

## Quick Test

**Server 1 par:**

```bash
# 1. Clear all logs
docker logs zoom-dashboard-api --tail 0 > /dev/null 2>&1
docker logs zoom-bot-server-api --tail 0 > /dev/null 2>&1

# 2. Test bot server health from main API container
docker exec zoom-dashboard-api node -e "require('http').get('http://bot-server:3001/health', (r) => {let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log('Health:', d))}).on('error',e=>console.error('Error:', e.message));"

# 3. Check bot server logs
docker logs zoom-bot-server-api --tail 20

# 4. If health works, test create endpoint
docker exec zoom-dashboard-api node -e "
const axios = require('axios');
axios.post('http://bot-server:3001/api/bots/create', {
  meetingId: '8421085087',
  password: '123456',
  joinUrl: 'https://zoom.us/j/8421085087?pwd=123456',
  videoCount: 0,
  audioCount: 20,
  nameType: 'Indian',
  meetingType: 'Normal Member',
  accountId: 'kOjrXedBRwGlbGiCyzQOyQ',
  clientId: '9bk9CyXgSgqggGe5InpVMA',
  clientSecret: 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'
}).then(r => console.log('Success')).catch(e => console.error('Error:', e.response?.data || e.message));
"

# 5. Check bot server logs
docker logs zoom-bot-server-api --tail 100
```


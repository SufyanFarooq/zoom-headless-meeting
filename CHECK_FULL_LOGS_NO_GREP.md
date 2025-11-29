# Check Full Logs Without Grep

## Problem
Grep se kuch nahi mil raha, matlab logs me expected output nahi hai.

## Solution: Check Raw Logs

**Server 1 par:**

```bash
# 1. Get FULL raw logs (no grep)
docker logs zoom-bot-server-api --tail 200

# 2. Check recent logs after meeting creation
# Pehle meeting create karein, phir immediately logs check karein
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Phir immediately logs check karein
docker logs zoom-bot-server-api --tail 100

# 3. Check if script execution is happening
docker logs zoom-bot-server-api --tail 200 | tail -50
```

## Possible Issues

1. **Logs cleared** - Container restart ke baad logs clear ho gaye
2. **Script not executing** - Script execution hi nahi ho rahi
3. **Error before logging** - Error pehle aa raha hai, logs baad me

## Alternative: Check Error Source Directly

**Server 1 par:**

```bash
# Check error message format in api.js
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 5 -B 5 "Failed to create"

# Check catch block
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 10 "catch (error)"

# Check where error.message is used
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -B 5 -A 5 "error.message"
```

## Check Script Execution

**Server 1 par:**

```bash
# Test script manually to see what it outputs
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash setup-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'kOjrXedBRwGlbGiCyzQOyQ' '9bk9CyXgSgqggGe5InpVMA' 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'"

# Check what compose file was generated
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml
```


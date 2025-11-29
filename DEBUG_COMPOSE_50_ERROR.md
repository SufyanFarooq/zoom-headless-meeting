# Debug compose-50-bots.yaml Error

## Problem
Code updated hai, file remove ho gayi hai, lekin abhi bhi error me `compose-50-bots.yaml` dikha raha hai.

## Debug Steps

### Step 1: Check Container Logs

**Server 1 par:**

```bash
# Get FULL logs after meeting creation
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📋 Expected compose file: compose-8421085087-bots.yaml"
# - "📋 Command to execute: docker-compose -f compose-8421085087-bots.yaml"
# - "Step 1: Generating compose file"
# - "Using Meeting ID:"
```

### Step 2: Verify Container Has Updated Code

**Server 1 par:**

```bash
# Check api.js in container
docker exec zoom-bot-server-api grep -n "composeFileName.*meetingId" /app/bot-project/bot-server/api.js

# Check if composeFileName is correct
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 2 -B 2 "composeFileName"

# Check line 211 specifically
docker exec zoom-bot-server-api sed -n '210,215p' /app/bot-project/bot-server/api.js
```

### Step 3: Check Script Execution

**Server 1 par:**

```bash
# Check if script is being called with MEETING_ID
docker logs zoom-bot-server-api --tail 200 | grep -E "(MEETING_ID|Step 1|Generated compose)"

# Check script output
docker logs zoom-bot-server-api --tail 200 | grep -A 10 "Step 1: Generating compose file"
```

### Step 4: Check Generated Compose Files

**Server 1 par:**

```bash
# Check what compose files exist
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml

# Check if compose-50-bots.yaml exists
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-50-bots.yaml 2>&1
```

### Step 5: Test Script Manually

**Server 1 par:**

```bash
# Test script with MEETING_ID
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash setup-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'kOjrXedBRwGlbGiCyzQOyQ' '9bk9CyXgSgqggGe5InpVMA' 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'"

# Check generated file
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml
```

## Possible Issues

1. **Container not rebuilt** - Old code cached
   - Solution: Force rebuild with `--no-cache`

2. **Volume mount issue** - Container using old code from image
   - Solution: Check volume mount path

3. **Error from previous execution** - Old error cached
   - Solution: Clear logs and test again

4. **Script execution failing** - Script me error hai
   - Solution: Check script execution logs

## Quick Fix

**Server 1 par:**

```bash
# 1. Stop container
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# 2. Remove old image
docker rmi zoom-headless-meeting-bot-server 2>/dev/null || true

# 3. Rebuild WITHOUT cache
cd ~/zoom-headless-meeting
docker build --no-cache -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# 4. Start container
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# 5. Verify code
docker exec zoom-bot-server-api grep -n "composeFileName.*meetingId" /app/bot-project/bot-server/api.js

# 6. Test and check logs
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 7. Check logs
docker logs zoom-bot-server-api --tail 100
```


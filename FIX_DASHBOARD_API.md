# Fix Dashboard API - compose-50-bots.yaml Error

## Problem
Dashboard UI se meeting create karte waqt `compose-50-bots.yaml` error aa raha hai, lekin manually script sahi kaam kar rahi hai.

## Changes Made

1. ✅ **Better error handling** - Script execution errors ko properly catch kiya
2. ✅ **Detailed logging** - Docker-compose command failures ko log kiya
3. ✅ **Compose file verification** - Script execution ke baad compose file verify kiya

## Server Deployment Steps

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Pull latest code
git pull origin main

# 2. Verify updated code
grep -n "composeFileName.*meetingId" bot-server/api.js
# Should show: const composeFileName = `compose-${meetingId}-bots.yaml`;

# 3. Rebuild bot server container (WITHOUT cache)
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api
docker build --no-cache -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# 4. Start container
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# 5. Check logs
docker logs zoom-bot-server-api --tail 10

# 6. Test from dashboard UI
# Go to dashboard and create a meeting

# 7. Check logs for detailed error
docker logs zoom-bot-server-api --tail 100
```

## Expected Behavior

✅ **Success:**
- Logs me `Expected compose file: compose-8421085087-bots.yaml` dikhega
- Logs me `Command to execute: docker-compose -f compose-8421085087-bots.yaml` dikhega
- Containers start honge with correct names
- NO `compose-50-bots.yaml` error

❌ **If still failing:**
- Check logs me detailed error messages
- Verify compose file was generated
- Check script execution output

## Debug Commands

**Server 1 par:**

```bash
# Check full logs
docker logs zoom-bot-server-api --tail 200

# Check if compose file exists after script execution
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml

# Test script manually
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash setup-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'kOjrXedBRwGlbGiCyzQOyQ' '9bk9CyXgSgqggGe5InpVMA' 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'"
```


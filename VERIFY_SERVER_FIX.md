# Verify Server Fix - Still Using compose-50-bots.yaml

## Problem
Server par abhi bhi `compose-50-bots.yaml` error aa raha hai despite code push and rebuild.

## Debug Steps

### Step 1: Check Container Logs

**Server 1 par:**

```bash
# Check recent logs
docker logs zoom-bot-server-api --tail 100 | grep -E "(compose|Meeting ID|Expected|Command)"

# Look for:
# - "Expected compose file: compose-8421085087-bots.yaml"
# - "Command to execute: docker-compose -f compose-8421085087-bots.yaml"
# - Should NOT see: "compose-50-bots.yaml"
```

### Step 2: Verify Container Has Updated Code

**Server 1 par:**

```bash
# Check if container has updated api.js
docker exec zoom-bot-server-api grep -n "composeFileName.*meetingId" /app/bot-server/api.js | head -3

# Should show:
# const composeFileName = `compose-${meetingId}-bots.yaml`;
```

### Step 3: Check Scripts in Container

**Server 1 par:**

```bash
# Check setup-flexible-bots.sh
docker exec zoom-bot-server-api grep -n "MEETING_ID" /app/bot-project/setup-flexible-bots.sh | head -5

# Check generate-flexible-bots.sh
docker exec zoom-bot-server-api grep -n "COMPOSE_FILE.*MEETING_ID" /app/bot-project/generate-flexible-bots.sh | head -3

# Check auto-setup-bots.sh
docker exec zoom-bot-server-api grep -n "COMPOSE_FILE" /app/bot-project/auto-setup-bots.sh | head -3
```

### Step 4: Force Rebuild Container

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Stop and remove container
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# Remove old image
docker rmi zoom-headless-meeting-bot-server 2>/dev/null || true

# Rebuild from scratch (no cache)
docker build --no-cache -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# Start container
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# Check logs
docker logs -f zoom-bot-server-api
```

### Step 5: Verify Files Are Updated

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Check api.js has latest code
grep -n "composeFileName.*meetingId" bot-server/api.js

# Check scripts are updated
grep -n "MEETING_ID" setup-flexible-bots.sh | head -3
grep -n "COMPOSE_FILE" auto-setup-bots.sh | head -3
```

### Step 6: Check Volume Mount

**Server 1 par:**

```bash
# Verify volume mount is working
docker exec zoom-bot-server-api ls -la /app/bot-project/bot-server/api.js

# Check if file is updated
docker exec zoom-bot-server-api grep -n "composeFileName.*meetingId" /app/bot-project/bot-server/api.js
```

## Common Issues

1. **Container not rebuilt** - Old image cached
   - Solution: Use `--no-cache` flag

2. **Volume mount issue** - Container using old code from image
   - Solution: Verify volume mount path is correct

3. **Scripts not updated** - Old scripts in container
   - Solution: Check scripts in `/app/bot-project/` directory

4. **Cache issue** - Docker build cache
   - Solution: Rebuild with `--no-cache`

## Quick Fix

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Pull latest code
git pull origin main

# 2. Verify files updated
grep -n "composeFileName.*meetingId" bot-server/api.js

# 3. Stop and remove container
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api

# 4. Rebuild WITHOUT cache
docker build --no-cache -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .

# 5. Start container
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server

# 6. Test
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# 7. Check logs
docker logs zoom-bot-server-api --tail 50 | grep -E "(compose|Meeting ID)"
```

## Expected Results

✅ **Success:**
- Logs me `compose-8421085087-bots.yaml` dikhega
- NO `compose-50-bots.yaml` error

❌ **Failure:**
- Agar abhi bhi `compose-50-bots.yaml` dikhe:
  1. Check container rebuild hua ya nahi
  2. Check volume mount correct hai ya nahi
  3. Check scripts updated hain ya nahi


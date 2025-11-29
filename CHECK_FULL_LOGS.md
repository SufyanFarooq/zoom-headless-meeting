# Check Full Logs - Find MEETING_ID Issue

## Problem
Error me abhi bhi `compose-50-bots.yaml` dikha raha hai, matlab MEETING_ID properly pass nahi ho raha.

## Step 1: Check Full Bot Server Logs

**Server 1 par:**

```bash
# Check ALL logs (including script output)
docker logs zoom-bot-server-api 2>&1 | tail -300

# Look for:
# - "⏳ Executing setup script"
# - "📝 Step 1: Generating compose file"
# - "Meeting ID from env:"
# - "Using Meeting ID:"
# - "Expected compose file:"
# - Script stdout/stderr
```

## Step 2: Check Script Execution Output

**Logs me ye dikhna chahiye:**

```
⏳ Executing setup script (timeout: 180s)...
   Step 1: Checking/ensuring zoom-bot:latest image exists...
   ✅ Image zoom-bot:latest found
   Step 2: Generating compose file...
   Step 3: Generating ZAK tokens (20 bots, ~2s each)...
   Step 4: Starting containers...
✅ Setup script completed
📋 Script output:
📝 Step 1: Generating compose file...
   Meeting ID from env: 8421085087
   Meeting ID from URL: 8421085087
   Using Meeting ID: 8421085087
✅ Using Meeting ID: 8421085087
📋 Generated compose files: compose-8421085087-bots.yaml
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
```

**Agar logs me `compose-50-bots.yaml` dikhe, to:**
- Script me MEETING_ID properly pass nahi ho raha
- Ya script old code use kar rahi hai

## Step 3: Test Script Manually

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Test script with MEETING_ID
MEETING_ID="8421085087" bash setup-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "kOjrXedBRwGlbGiCyzQOyQ" "9bk9CyXgSgqggGe5InpVMA" "OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"

# Check output
ls -la compose-*.yaml
# Should see: compose-8421085087-bots.yaml
# NOT: compose-50-bots.yaml
```

## Step 4: Check Bot Server Container Scripts

**Verify container me scripts updated hain:**

```bash
# Check scripts in container
docker exec zoom-bot-server-api grep -n "MEETING_ID" /app/bot-project/setup-flexible-bots.sh | head -5
docker exec zoom-bot-server-api grep -n "COMPOSE_FILE" /app/bot-project/generate-flexible-bots.sh | head -3

# Should show MEETING_ID support
```

## Step 5: Check Environment Variable

**Test if MEETING_ID is being passed:**

```bash
# Check command being executed
docker exec zoom-bot-server-api env | grep MEETING_ID

# Or check logs for command
docker logs zoom-bot-server-api 2>&1 | grep -E "(MEETING_ID|command)"
```

## Quick Fix

**If scripts not updated in container:**

```bash
# Rebuild bot server
docker stop zoom-bot-server-api
docker rm zoom-bot-server-api
cd ~/zoom-headless-meeting
docker build -f Dockerfile.bot-server -t zoom-headless-meeting-bot-server .
docker run -d --name zoom-bot-server-api -p 3001:3001 \
  -v ~/zoom-headless-meeting:/app/bot-project \
  -v /var/run/docker.sock:/var/run/docker.sock \
  zoom-headless-meeting-bot-server
```

## Summary

**Check:**
1. Full bot server logs (all output)
2. Script execution logs
3. MEETING_ID in logs
4. Manual script test

**Share full bot server logs after meeting creation!**


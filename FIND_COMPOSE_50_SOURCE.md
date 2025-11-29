# Find Where compose-50-bots.yaml is Coming From

## Problem
File remove ho gayi hai, lekin error me abhi bhi `compose-50-bots.yaml` dikha raha hai.

## Debug Steps

### Step 1: Check Full Bot Server Logs

**Server 1 par:**

```bash
# Get full logs
docker logs zoom-bot-server-api --tail 200 > /tmp/bot-logs.txt

# Check for compose file references
grep -n "compose" /tmp/bot-logs.txt

# Check for Meeting ID
grep -n "Meeting ID\|MEETING_ID" /tmp/bot-logs.txt

# Check script execution
grep -n "Step 1\|Generated\|Expected" /tmp/bot-logs.txt
```

### Step 2: Check Scripts for Hardcoded compose-50-bots.yaml

**Server 1 par:**

```bash
# Check all scripts for compose-50-bots
docker exec zoom-bot-server-api grep -rn "compose-50-bots" /app/bot-project/*.sh /app/bot-project/*.py 2>/dev/null

# Check setup-flexible-bots.sh
docker exec zoom-bot-server-api grep -n "compose" /app/bot-project/setup-flexible-bots.sh

# Check generate-flexible-bots.sh
docker exec zoom-bot-server-api grep -n "compose" /app/bot-project/generate-flexible-bots.sh

# Check auto-setup-bots.sh
docker exec zoom-bot-server-api grep -n "compose" /app/bot-project/auto-setup-bots.sh
```

### Step 3: Check Error Message Source

**Server 1 par:**

```bash
# The error shows: "Command failed: docker-compose -f compose-50-bots.yaml"
# This means the actual command being executed has compose-50-bots.yaml

# Check where this command is coming from
docker logs zoom-bot-server-api --tail 200 | grep -B 10 -A 10 "compose-50-bots"
```

### Step 4: Test Script Manually

**Server 1 par:**

```bash
# Test script execution manually
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash -x setup-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'kOjrXedBRwGlbGiCyzQOyQ' '9bk9CyXgSgqggGe5InpVMA' 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS' 2>&1" | grep -E "(compose|MEETING_ID)"
```

## Possible Sources

1. **Script calling docker-compose** - Script me docker-compose call ho sakta hai
2. **Error message from old code** - Error catch block me old message
3. **Fallback in script** - Script me fallback jo old file use kar raha hai
4. **Cached command** - Old command cached hai

## Quick Check

**Server 1 par:**

```bash
# 1. Check full logs
docker logs zoom-bot-server-api --tail 200

# 2. Check scripts
docker exec zoom-bot-server-api grep -rn "compose-50" /app/bot-project/

# 3. Check error message in api.js
docker exec zoom-bot-server-api grep -n "compose-50" /app/bot-project/bot-server/api.js

# 4. Share full logs
docker logs zoom-bot-server-api --tail 200
```


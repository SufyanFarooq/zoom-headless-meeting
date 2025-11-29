# Check Script Execution - compose-50-bots.yaml Still Appearing

## Problem
Container me updated code hai, lekin error me abhi bhi `compose-50-bots.yaml` dikha raha hai.

## Debug Steps

### Step 1: Check Full Bot Server Logs

**Server 1 par:**

```bash
# Check ALL logs after meeting creation
docker logs zoom-bot-server-api --tail 200

# Look for:
# - "📋 Expected compose file: compose-8421085087-bots.yaml"
# - "📋 Command to execute: docker-compose -f compose-8421085087-bots.yaml"
# - Script execution output
# - Where compose-50-bots.yaml is coming from
```

### Step 2: Check Script Execution Output

**Server 1 par:**

```bash
# Check if script is generating correct compose file
docker logs zoom-bot-server-api --tail 200 | grep -A 10 "Step 1: Generating compose file"

# Should see:
# "Using Meeting ID: 8421085087"
# "Generated compose-8421085087-bots.yaml"
```

### Step 3: Check Scripts in Container

**Server 1 par:**

```bash
# Check setup-flexible-bots.sh
docker exec zoom-bot-server-api cat /app/bot-project/setup-flexible-bots.sh | grep -A 5 "MEETING_ID"

# Check generate-flexible-bots.sh
docker exec zoom-bot-server-api cat /app/bot-project/generate-flexible-bots.sh | grep -A 5 "COMPOSE_FILE"

# Check auto-setup-bots.sh
docker exec zoom-bot-server-api cat /app/bot-project/auto-setup-bots.sh | grep -A 3 "COMPOSE_FILE"
```

### Step 4: Check Generated Compose Files

**Server 1 par:**

```bash
# Check what compose files exist
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml

# Should see:
# compose-8421085087-bots.yaml ✅
# Should NOT see: compose-50-bots.yaml ❌
```

### Step 5: Test Script Manually in Container

**Server 1 par:**

```bash
# Test script execution manually
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash setup-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'kOjrXedBRwGlbGiCyzQOyQ' '9bk9CyXgSgqggGe5InpVMA' 'OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'"

# Check output
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml
```

## Possible Issues

1. **Scripts not updated in container** - Volume mount me old scripts
   - Solution: Check scripts in `/app/bot-project/`

2. **Script execution failing** - Script fail ho rahi hai aur fallback me old file use ho raha hai
   - Solution: Check script execution logs

3. **Error message from old code** - Error catch block me old message
   - Solution: Check error handling in api.js

4. **Script calling docker-compose internally** - Script me docker-compose call hai jo old file use kar raha hai
   - Solution: Check scripts for docker-compose calls

## Quick Fix

**Server 1 par:**

```bash
# 1. Check full logs
docker logs zoom-bot-server-api --tail 200 > /tmp/bot-server-logs.txt
cat /tmp/bot-server-logs.txt | grep -E "(compose|Meeting ID|Expected|Command|Error)"

# 2. Check scripts
docker exec zoom-bot-server-api grep -n "compose-50-bots" /app/bot-project/*.sh /app/bot-project/*.py 2>/dev/null

# 3. Check generated files
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-*.yaml

# 4. Share logs for analysis
docker logs zoom-bot-server-api --tail 200
```


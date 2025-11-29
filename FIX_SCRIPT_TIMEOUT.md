# Fix Script Timeout/Execution Issue

## Problem
Logs me script execution ke baad kuch nahi dikha raha. Script fail ho rahi hai ya timeout ho rahi hai.

## Debug Steps

### Step 1: Check Script Execution Error

**Server 1 par:**

```bash
# Check if script exists and is executable
cd ~/zoom-headless-meeting
ls -la setup-flexible-bots.sh generate-flexible-bots.sh

# Make executable
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh update-compose-zak.py

# Test script manually
MEETING_ID="8421085087" bash setup-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "kOjrXedBRwGlbGiCyzQOyQ" "9bk9CyXgSgqggGe5InpVMA" "OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"

# Check output
ls -la compose-*.yaml
```

### Step 2: Check Script in Container

**Verify scripts in bot server container:**

```bash
# Check scripts exist
docker exec zoom-bot-server-api ls -la /app/bot-project/setup-flexible-bots.sh
docker exec zoom-bot-server-api ls -la /app/bot-project/generate-flexible-bots.sh

# Check permissions
docker exec zoom-bot-server-api ls -la /app/bot-project/*.sh

# Make executable in container
docker exec zoom-bot-server-api chmod +x /app/bot-project/*.sh
docker exec zoom-bot-server-api chmod +x /app/bot-project/update-compose-zak.py

# Test script in container
docker exec zoom-bot-server-api bash -c "cd /app/bot-project && MEETING_ID='8421085087' bash generate-flexible-bots.sh 0 20 'https://zoom.us/j/8421085087?pwd=123456' 'Bot' 'profile-pics/users.txt' 'Indian' '8421085087'"
```

### Step 3: Check Error Handling

**Bot server code me error handling check karein:**

```bash
# Check bot server code
docker exec zoom-bot-server-api cat /app/bot-project/bot-server/api.js | grep -A 10 "catch (error)"
```

### Step 4: Add More Logging

**Bot server code me more logging add karein to see what's happening.**

## Quick Fix

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# 1. Make scripts executable
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh update-compose-zak.py

# 2. Test script manually
MEETING_ID="8421085087" bash setup-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "kOjrXedBRwGlbGiCyzQOyQ" "9bk9CyXgSgqggGe5InpVMA" "OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"

# 3. Check output
ls -la compose-*.yaml

# 4. If script works manually, check container
docker exec zoom-bot-server-api chmod +x /app/bot-project/*.sh
docker exec zoom-bot-server-api chmod +x /app/bot-project/update-compose-zak.py

# 5. Restart bot server
docker restart zoom-bot-server-api
```

## Summary

**Check:**
1. Script permissions
2. Manual script test
3. Container scripts
4. Error handling

**Pehle manual script test karein - agar manually kaam kare, to issue container me hai!**


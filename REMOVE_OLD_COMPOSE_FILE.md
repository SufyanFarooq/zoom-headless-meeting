# Remove Old compose-50-bots.yaml File

## Problem
Old `compose-50-bots.yaml` file exist kar rahi hai, jo confusion create kar sakti hai.

## Solution

### Step 1: Remove Old Compose File

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# Remove old compose file
rm -f compose-50-bots.yaml

# Verify removed
ls -la compose-50-bots.yaml 2>&1
# Should show: "No such file or directory"

# Check other compose files
ls -la compose-*.yaml
# Should only show meeting-specific files like:
# compose-8421085087-bots.yaml ✅
```

### Step 2: Remove from Container (if exists)

**Server 1 par:**

```bash
# Check if file exists in container
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-50-bots.yaml 2>&1

# Remove from container
docker exec zoom-bot-server-api rm -f /app/bot-project/compose-50-bots.yaml

# Verify removed
docker exec zoom-bot-server-api ls -la /app/bot-project/compose-50-bots.yaml 2>&1
# Should show: "No such file or directory"
```

### Step 3: Clean Up All Old Compose Files (Optional)

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting

# List all compose files
ls -la compose-*.yaml

# Remove old compose-50-bots.yaml
rm -f compose-50-bots.yaml

# Optional: Remove all old compose files (be careful!)
# Only if you want to clean up all old meeting files
# rm -f compose-*-bots.yaml

# Keep only current meeting files
# Or let them accumulate (they're meeting-specific, so safe)
```

### Step 4: Test Again

**Server 1 par:**

```bash
# Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'

# Check logs
docker logs zoom-bot-server-api --tail 50 | grep -E "(compose|Meeting ID|Expected)"

# Should see:
# "Expected compose file: compose-8421085087-bots.yaml" ✅
# "Command to execute: docker-compose -f compose-8421085087-bots.yaml" ✅
# Should NOT see: "compose-50-bots.yaml" ❌
```

## Quick Command

**Server 1 par:**

```bash
cd ~/zoom-headless-meeting && \
rm -f compose-50-bots.yaml && \
docker exec zoom-bot-server-api rm -f /app/bot-project/compose-50-bots.yaml && \
echo "✅ Removed compose-50-bots.yaml from host and container"
```


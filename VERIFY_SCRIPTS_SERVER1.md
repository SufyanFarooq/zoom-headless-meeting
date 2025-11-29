# Verify Scripts on Server 1 - Already Updated!

## Current Status
- ✅ Project: `~/zoom-headless-meeting`
- ✅ `.git` folder exists
- ✅ Files updated: Nov 28 14:03
- ✅ Scripts exist: `generate-flexible-bots.sh`, `setup-flexible-bots.sh`, `bot-server/api.js`

## Verify Scripts Are Updated

**Server 1 par Browser SSH me ye commands:**

```bash
cd ~/zoom-headless-meeting

# 1. Check generate-flexible-bots.sh has MEETING_ID support
grep -n "MEETING_ID" generate-flexible-bots.sh | head -5
# Should show:
# MEETING_ID="${7:-}"
# if [ -z "$MEETING_ID" ]; then
# COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"

# 2. Check setup-flexible-bots.sh has MEETING_ID support
grep -n "MEETING_ID" setup-flexible-bots.sh | head -5
# Should show MEETING_ID handling

# 3. Check bot-server/api.js passes MEETING_ID
grep -n "MEETING_ID" bot-server/api.js | head -5
# Should show: MEETING_ID="${meetingId}" in command

# 4. Check compose file name uses MEETING_ID
grep -n "COMPOSE_FILE" generate-flexible-bots.sh
# Should show: COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"
```

## If Scripts Are Updated

**Then just:**

```bash
cd ~/zoom-headless-meeting

# 1. Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# 2. Build Docker image (if missing)
docker images zoom-bot:latest
# If not found:
docker build -t zoom-bot:latest . --platform linux/amd64

# 3. Restart bot server
docker restart zoom-bot-server-api

# 4. Test 2nd meeting
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":30,"videoCount":0,"audioCount":30,"nameType":"Indian","meetingType":"Normal Member"}'
```

## If Scripts Need Update

**Git pull karein:**

```bash
cd ~/zoom-headless-meeting

# Pull latest code
git pull origin main

# Verify again
grep -n "MEETING_ID" generate-flexible-bots.sh | head -5

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
```

## Summary

**Current:** Files already updated (Nov 28 14:03)  
**Action:** Verify MEETING_ID support, then test  
**No need for /tmp or /opt** - work in `~/zoom-headless-meeting`

Pehle verify karein ki scripts me MEETING_ID support hai ya nahi!


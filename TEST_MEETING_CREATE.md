# Test Meeting Creation - Check Logs

## Step 1: Create Meeting and Watch Logs

**Server 1 par 2 terminals open karein:**

**Terminal 1 - Watch logs:**
```bash
# Watch bot server logs in real-time
docker logs -f zoom-bot-server-api
```

**Terminal 2 - Create meeting:**
```bash
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

## Step 2: Check Logs Output

**Logs me ye dikhna chahiye:**

```
📥 Received request body: {"meetingId":"8421085087",...}
📋 Extracted values: { meetingId: '8421085087', ... }
📋 Expected compose file: compose-8421085087-bots.yaml
📋 Meeting ID used: 8421085087
📝 Step 1: Generating compose file...
   Meeting ID from env: 8421085087
   Meeting ID from URL: 8421085087
   Using Meeting ID: 8421085087
✅ Using Meeting ID: 8421085087
```

**Agar logs me `compose-50-bots.yaml` dikhe, to:**

1. Scripts me MEETING_ID properly pass nahi ho raha
2. Ya script old code use kar raha hai

## Step 3: Check Generated Files

**After meeting creation attempt:**

```bash
# Check what compose files were created
cd /opt/zoom-headless-meeting
ls -la compose-*.yaml

# Should see: compose-8421085087-bots.yaml
# NOT: compose-50-bots.yaml
```

## Step 4: Verify Scripts

**Check scripts are updated:**

```bash
cd /opt/zoom-headless-meeting

# Check generate script
grep -n "MEETING_ID" generate-flexible-bots.sh
grep -n "COMPOSE_FILE" generate-flexible-bots.sh

# Check setup script
grep -n "MEETING_ID" setup-flexible-bots.sh
```

**Expected output:**
- `MEETING_ID="${7:-}"` in generate script
- `COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"` in generate script
- `MEETING_ID="${MEETING_ID:-${MEETING_ID_FROM_URL}}"` in setup script

## Step 5: Manual Test

**Test script directly:**

```bash
cd /opt/zoom-headless-meeting

# Test with meeting ID
MEETING_ID="8421085087" bash generate-flexible-bots.sh 0 20 "https://zoom.us/j/8421085087?pwd=123456" "Bot" "profile-pics/users.txt" "Indian" "8421085087"

# Check output
ls -la compose-8421085087-bots.yaml
cat compose-8421085087-bots.yaml | head -20
```

**Expected:**
- File: `compose-8421085087-bots.yaml`
- Container names: `zoom-bot-8421085087-1`, `zoom-bot-8421085087-2`, etc.

## Summary

**Test steps:**
1. Watch logs: `docker logs -f zoom-bot-server-api`
2. Create meeting via API
3. Check logs for MEETING_ID
4. Check generated compose files
5. Verify scripts are updated

**Share logs output, phir exact issue identify karte hain.**


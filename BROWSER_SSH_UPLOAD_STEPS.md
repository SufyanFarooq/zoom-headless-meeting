# Browser SSH Upload Steps - updated-scripts.tar.gz

## Step 1: Download File Locally

**Local machine par (yahan se):**

```bash
# File location check
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"
ls -lh updated-scripts.tar.gz

# File should be: updated-scripts.tar.gz (12KB)
```

**File download karein:**
- File explorer me jao: `/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample`
- `updated-scripts.tar.gz` file ko download/copy karein

## Step 2: Browser SSH se Upload

**Server 1 par Browser SSH:**

1. **GCP Console me jao:**
   - Google Cloud Console → Compute Engine → VM Instances
   - Server 1 VM select karein
   - **SSH** button click karein (Browser window open hoga)

2. **File Upload:**
   - Browser SSH window me **gear icon** (⚙️) ya **three dots** (⋮) click karein
   - **"Upload file"** option select karein
   - `updated-scripts.tar.gz` file select karein
   - Upload karein

3. **File location check:**
   ```bash
   # Browser SSH me
   ls -lh /tmp/updated-scripts.tar.gz
   # Should show: updated-scripts.tar.gz
   ```

## Step 3: Extract Files on Server 1

**Browser SSH me ye commands run karein:**

```bash
# Go to project directory
cd /opt/zoom-headless-meeting

# Extract files
tar -xzf /tmp/updated-scripts.tar.gz

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Verify scripts are updated
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
# Should show: MEETING_ID="${7:-}"

grep -n "COMPOSE_FILE" generate-flexible-bots.sh | head -3
# Should show: COMPOSE_FILE="compose-${MEETING_ID}-bots.yaml"

# Check bot-server/api.js
grep -n "MEETING_ID" bot-server/api.js | head -3
# Should show MEETING_ID in command

# Cleanup
rm /tmp/updated-scripts.tar.gz
```

## Step 4: Remove Old Compose Files

```bash
# Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# Verify
ls -la compose-*.yaml
# Should be empty or no files
```

## Step 5: Build Docker Image

```bash
# Build image (10-30 minutes)
docker build -t zoom-bot:latest . --platform linux/amd64

# Verify
docker images zoom-bot:latest
```

## Step 6: Restart Bot Server

```bash
# Restart bot server
docker restart zoom-bot-server-api

# Check logs
docker logs zoom-bot-server-api --tail 20
```

## Step 7: Test Meeting Creation

**Watch logs:**
```bash
docker logs -f zoom-bot-server-api
```

**Create meeting (another terminal or same terminal):**
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

## Complete Commands (Copy-Paste)

**Browser SSH me:**

```bash
# 1. Extract files
cd /opt/zoom-headless-meeting
tar -xzf /tmp/updated-scripts.tar.gz

# 2. Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# 3. Verify
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
grep -n "COMPOSE_FILE" generate-flexible-bots.sh | head -3

# 4. Remove old files
rm -f compose-50-bots.yaml compose-*-bots.yaml
rm /tmp/updated-scripts.tar.gz

# 5. Build Docker image
docker build -t zoom-bot:latest . --platform linux/amd64

# 6. Verify image
docker images zoom-bot:latest

# 7. Restart bot server
docker restart zoom-bot-server-api

# 8. Check logs
docker logs zoom-bot-server-api --tail 20
```

## Summary

**Steps:**
1. ✅ Download `updated-scripts.tar.gz` locally
2. ✅ Browser SSH → Upload file → `/tmp/updated-scripts.tar.gz`
3. ✅ Extract: `tar -xzf /tmp/updated-scripts.tar.gz`
4. ✅ Make executable: `chmod +x *.sh update-compose-zak.py`
5. ✅ Verify scripts updated
6. ✅ Remove old compose files
7. ✅ Build Docker image
8. ✅ Restart bot server
9. ✅ Test meeting creation

Ye steps follow karein!


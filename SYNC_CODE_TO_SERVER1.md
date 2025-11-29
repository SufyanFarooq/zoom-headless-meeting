# Sync Code to Server 1 - Fix Git Issue

## Problem
`/opt/zoom-headless-meeting` is not a git repository. Code needs to be synced from git repo.

## Solution Options

### Option 1: Copy Updated Files Manually (Quick Fix)

**Local machine se Server 1 par copy karein:**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy updated scripts to Server 1
scp generate-flexible-bots.sh user@SERVER1_IP:/opt/zoom-headless-meeting/
scp setup-flexible-bots.sh user@SERVER1_IP:/opt/zoom-headless-meeting/
scp bot-server/api.js user@SERVER1_IP:/opt/zoom-headless-meeting/bot-server/
scp update-compose-zak.py user@SERVER1_IP:/opt/zoom-headless-meeting/
```

**Ya tar.gz package bana ke copy karein:**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Create package with updated files
tar -czf updated-scripts.tar.gz \
  generate-flexible-bots.sh \
  setup-flexible-bots.sh \
  bot-server/api.js \
  update-compose-zak.py

# Copy to Server 1
scp updated-scripts.tar.gz user@SERVER1_IP:/tmp/

# Server 1 par extract
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting
tar -xzf /tmp/updated-scripts.tar.gz
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
```

### Option 2: Initialize Git in /opt/zoom-headless-meeting

**Server 1 par:**

```bash
cd /opt/zoom-headless-meeting

# Initialize git
git init

# Add remote
git remote add origin https://github.com/SufyanFarooq/zoom-headless-meeting.git

# Fetch and pull
git fetch origin
git pull origin main
```

### Option 3: Clone Fresh and Copy Config

**Server 1 par:**

```bash
# Clone to temp location
cd /tmp
git clone https://github.com/SufyanFarooq/zoom-headless-meeting.git

# Copy updated files
cp -r zoom-headless-meeting/generate-flexible-bots.sh /opt/zoom-headless-meeting/
cp -r zoom-headless-meeting/setup-flexible-bots.sh /opt/zoom-headless-meeting/
cp -r zoom-headless-meeting/bot-server/api.js /opt/zoom-headless-meeting/bot-server/
cp -r zoom-headless-meeting/update-compose-zak.py /opt/zoom-headless-meeting/

# Make executable
chmod +x /opt/zoom-headless-meeting/*.sh
chmod +x /opt/zoom-headless-meeting/update-compose-zak.py

# Cleanup
rm -rf /tmp/zoom-headless-meeting
```

### Option 4: Use rsync (If Available)

**Local machine se:**

```bash
# Sync specific files
rsync -avz \
  generate-flexible-bots.sh \
  setup-flexible-bots.sh \
  bot-server/api.js \
  update-compose-zak.py \
  user@SERVER1_IP:/opt/zoom-headless-meeting/
```

## Recommended: Option 1 (Manual Copy)

**Quickest and safest:**

**Local machine par:**
```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Create package
tar -czf updated-scripts.tar.gz \
  generate-flexible-bots.sh \
  setup-flexible-bots.sh \
  bot-server/api.js \
  update-compose-zak.py

# Copy to Server 1 (replace SERVER1_IP)
scp updated-scripts.tar.gz user@SERVER1_IP:/tmp/
```

**Server 1 par:**
```bash
cd /opt/zoom-headless-meeting

# Extract
tar -xzf /tmp/updated-scripts.tar.gz

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Verify
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
# Should show: MEETING_ID="${7:-}"

# Cleanup
rm /tmp/updated-scripts.tar.gz
```

## After Syncing Code

**Server 1 par:**

```bash
# 1. Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# 2. Build Docker image
docker build -t zoom-bot:latest . --platform linux/amd64

# 3. Restart bot server
docker restart zoom-bot-server-api

# 4. Test meeting creation
curl -X POST http://localhost:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"meetingId":"8421085087","password":"123456","membersCount":20,"videoCount":0,"audioCount":20,"nameType":"Indian","meetingType":"Normal Member"}'
```

## Summary

**Problem:** `/opt/zoom-headless-meeting` is not a git repo  
**Solution:** Copy updated files manually  
**Files to update:**
- `generate-flexible-bots.sh`
- `setup-flexible-bots.sh`
- `bot-server/api.js`
- `update-compose-zak.py`


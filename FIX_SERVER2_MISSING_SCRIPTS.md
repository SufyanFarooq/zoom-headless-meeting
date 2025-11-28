# Fix Server 2 - Missing Scripts

## Problem

Server 2 par ye scripts missing hain:
- `setup-flexible-bots.sh`
- `generate-flexible-bots.sh`
- `auto-setup-bots.sh`
- `update-compose-zak.py`

**Error:** `Script not found at: /app/bot-project/setup-flexible-bots.sh`

## Solution: Copy Missing Scripts to Server 2

### Option 1: Copy Scripts from Server 1 (Quick Fix)

**Server 1 se Server 2 par copy karein:**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# Scripts copy karein
scp setup-flexible-bots.sh user@35.227.36.166:/opt/zoom-headless-meeting/
scp generate-flexible-bots.sh user@35.227.36.166:/opt/zoom-headless-meeting/
scp auto-setup-bots.sh user@35.227.36.166:/opt/zoom-headless-meeting/
scp update-compose-zak.py user@35.227.36.166:/opt/zoom-headless-meeting/

# Permissions fix karein
ssh user@35.227.36.166
cd /opt/zoom-headless-meeting
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh
chmod +x update-compose-zak.py
```

### Option 2: Using gcloud (GCP Server 2)

```bash
# Server 1 se scripts copy karein
gcloud compute scp setup-flexible-bots.sh zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c
gcloud compute scp generate-flexible-bots.sh zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c
gcloud compute scp auto-setup-bots.sh zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c
gcloud compute scp update-compose-zak.py zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c

# Permissions fix
gcloud compute ssh zoom-bots-server --zone=us-east1-c --command="cd /opt/zoom-headless-meeting && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py"
```

### Option 3: Browser SSH Upload

1. **Server 1 se scripts download karein** (ya local machine se)
2. **GCP Browser SSH** open karein
3. **Upload file** se scripts upload karein
4. **Move to correct location:**

```bash
# Browser SSH me
cd /opt/zoom-headless-meeting
mv ~/setup-flexible-bots.sh .
mv ~/generate-flexible-bots.sh .
mv ~/auto-setup-bots.sh .
mv ~/update-compose-zak.py .
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

### Option 4: One-Line Copy (All Scripts)

```bash
# Server 1 par
cd /opt/zoom-headless-meeting
tar -czf scripts.tar.gz setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py

# Copy to Server 2
scp scripts.tar.gz user@35.227.36.166:/opt/zoom-headless-meeting/

# Server 2 par extract
ssh user@35.227.36.166
cd /opt/zoom-headless-meeting
tar -xzf scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
rm scripts.tar.gz
```

## Verify Scripts Exist

**Server 2 par check karein:**

```bash
cd /opt/zoom-headless-meeting
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py

# Expected output:
# -rwxr-xr-x 1 user user ... setup-flexible-bots.sh
# -rwxr-xr-x 1 user user ... generate-flexible-bots.sh
# -rwxr-xr-x 1 user user ... auto-setup-bots.sh
# -rwxr-xr-x 1 user user ... update-compose-zak.py
```

## Restart Bot Server Container

**Scripts copy karne ke baad container restart karein:**

```bash
cd /opt/zoom-headless-meeting
docker compose -f docker-compose.bot-server.yml restart
```

## Test Again

**Ab meeting create karein:**

```bash
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member",
    "timeoutSeconds": 7200
  }'
```

**Expected:** Success! Server 2 par bots create ho jayenge.

## Complete File List for Server 2

**Required Files:**
- ✅ `setup-flexible-bots.sh` ⚠️ MISSING
- ✅ `generate-flexible-bots.sh` ⚠️ MISSING
- ✅ `auto-setup-bots.sh` ⚠️ MISSING
- ✅ `update-compose-zak.py` ⚠️ MISSING
- ✅ `bot-server/` ✅
- ✅ `build/` ✅
- ✅ `lib/` ✅
- ✅ `videos/` ✅
- ✅ `profile-pics/` ✅
- ✅ `bin/` ✅
- ✅ `compose-50-bots.yaml` ✅
- ✅ `config.toml` ✅

## Quick Fix Commands (Copy-Paste)

```bash
# Server 1 par (ya local machine se)
cd /opt/zoom-headless-meeting  # ya project directory

# Scripts tar create karein
tar -czf server2-scripts.tar.gz \
  setup-flexible-bots.sh \
  generate-flexible-bots.sh \
  auto-setup-bots.sh \
  update-compose-zak.py

# Server 2 par copy (choose method)
# Method 1: scp
scp server2-scripts.tar.gz user@35.227.36.166:/opt/zoom-headless-meeting/

# Method 2: gcloud
gcloud compute scp server2-scripts.tar.gz zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c

# Server 2 par extract
ssh user@35.227.36.166  # ya gcloud compute ssh
cd /opt/zoom-headless-meeting
tar -xzf server2-scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
rm server2-scripts.tar.gz

# Restart bot server
docker compose -f docker-compose.bot-server.yml restart
```

## Summary

**Problem:** Server 2 par 4 scripts missing hain
**Solution:** Server 1 se scripts copy karein
**Files:** 
- `setup-flexible-bots.sh`
- `generate-flexible-bots.sh`
- `auto-setup-bots.sh`
- `update-compose-zak.py`

**After fix:** Server 2 par bots create ho jayenge! ✅


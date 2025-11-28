# Copy Missing Scripts Only - Server 2

## Current Situation
- ✅ Package already uploaded: `bot-server-only.tar.gz`
- ✅ Files extracted: `/opt/zoom-headless-meeting`
- ❌ Missing: 4 scripts only

## Solution: Copy Only Missing Scripts

### Option 1: Server 1 se Direct Copy (Easiest) ⭐

**Server 1 par scripts tar create karein:**

```bash
# Server 1 par
cd /opt/zoom-headless-meeting
tar -czf missing-scripts.tar.gz \
  setup-flexible-bots.sh \
  generate-flexible-bots.sh \
  auto-setup-bots.sh \
  update-compose-zak.py
```

**Server 2 par copy karein (GCP):**

```bash
# Using gcloud
gcloud compute scp missing-scripts.tar.gz zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c

# Server 2 par extract
gcloud compute ssh zoom-bots-server --zone=us-east1-c --command="cd /opt/zoom-headless-meeting && tar -xzf missing-scripts.tar.gz && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && rm missing-scripts.tar.gz"
```

### Option 2: Browser SSH Upload (No Server 1 Needed)

**Step 1: Local Machine se Scripts Download Karein**

```bash
# Local machine par (Mac)
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Scripts tar create karein
tar -czf missing-scripts.tar.gz \
  setup-flexible-bots.sh \
  generate-flexible-bots.sh \
  auto-setup-bots.sh \
  update-compose-zak.py
```

**Step 2: GCP Browser SSH me Upload Karein**

1. GCP Console → Compute Engine → VM instances
2. `zoom-bots-server` ke saamne **"SSH"** click karein
3. Browser SSH me **"⚙️ Settings"** → **"Upload file"**
4. `missing-scripts.tar.gz` select karein
5. Upload ho jayega

**Step 3: Server 2 par Extract Karein**

Browser SSH terminal me:

```bash
cd /opt/zoom-headless-meeting
tar -xzf ~/missing-scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
rm ~/missing-scripts.tar.gz

# Verify
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

### Option 3: Individual Scripts Copy (If Tar Nahi Chahiye)

**Browser SSH me individually upload karein:**

1. **setup-flexible-bots.sh** upload karein
2. **generate-flexible-bots.sh** upload karein
3. **auto-setup-bots.sh** upload karein
4. **update-compose-zak.py** upload karein

Phir move karein:

```bash
cd /opt/zoom-headless-meeting
mv ~/setup-flexible-bots.sh .
mv ~/generate-flexible-bots.sh .
mv ~/auto-setup-bots.sh .
mv ~/update-compose-zak.py .
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

### Option 4: Using wget/curl (If Server 1 Has Public URL)

**Agar Server 1 par web server start karein:**

```bash
# Server 1 par (temporary)
cd /opt/zoom-headless-meeting
python3 -m http.server 8000

# Server 2 par download
wget http://SERVER1_IP:8000/setup-flexible-bots.sh
wget http://SERVER1_IP:8000/generate-flexible-bots.sh
wget http://SERVER1_IP:8000/auto-setup-bots.sh
wget http://SERVER1_IP:8000/update-compose-zak.py
chmod +x *.sh *.py
```

## Quick Commands (Copy-Paste)

### On Local Machine (Mac):

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"
tar -czf missing-scripts.tar.gz \
  setup-flexible-bots.sh \
  generate-flexible-bots.sh \
  auto-setup-bots.sh \
  update-compose-zak.py
```

**Phir Browser SSH se upload karein aur extract:**

```bash
# Browser SSH me
cd /opt/zoom-headless-meeting
tar -xzf ~/missing-scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
rm ~/missing-scripts.tar.gz
docker compose -f docker-compose.bot-server.yml restart
```

## Verify Scripts Exist

```bash
# Server 2 par
cd /opt/zoom-headless-meeting
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py

# Expected output:
# -rwxr-xr-x 1 user user ... setup-flexible-bots.sh
# -rwxr-xr-x 1 user user ... generate-flexible-bots.sh
# -rwxr-xr-x 1 user user ... auto-setup-bots.sh
# -rwxr-xr-x 1 user user ... update-compose-zak.py
```

## Test After Copy

```bash
# Meeting create karein
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
    "meetingType": "Normal Member"
  }'
```

**Expected:** Success! Server 2 par bots create ho jayenge.

## Summary

**Question:** Kya phir se package upload karna padega?  
**Answer:** ❌ NO! Sirf 4 scripts copy karein

**Files Needed:**
- `setup-flexible-bots.sh`
- `generate-flexible-bots.sh`
- `auto-setup-bots.sh`
- `update-compose-zak.py`

**Method:** Browser SSH upload (easiest) ya Server 1 se copy

**Package phir se upload karne ki zarurat nahi!** ✅


# Extract Scripts on Server 2 - Fix

## Current Situation
- ✅ File uploaded: `missing-scripts.tar.gz` (10KB)
- ✅ Location: `/opt/zoom-headless-meeting/missing-scripts.tar.gz`
- ❌ Extract nahi hua (wrong path use kiya)

## Correct Commands (Copy-Paste)

### Step 1: Extract Scripts

```bash
# Current directory me extract karein (not ~/)
cd /opt/zoom-headless-meeting
tar -xzf missing-scripts.tar.gz

# Verify scripts extract ho gaye
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

### Step 2: Permissions Set Karein

```bash
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

### Step 3: Verify

```bash
# Check all scripts exist
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py

# Expected output:
# -rwxr-xr-x 1 user user ... setup-flexible-bots.sh
# -rwxr-xr-x 1 user user ... generate-flexible-bots.sh
# -rwxr-xr-x 1 user user ... auto-setup-bots.sh
# -rwxr-xr-x 1 user user ... update-compose-zak.py
```

### Step 4: Restart Bot Server

```bash
docker compose -f docker-compose.bot-server.yml restart
```

## Complete Sequence (One Go)

```bash
cd /opt/zoom-headless-meeting
tar -xzf missing-scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
docker compose -f docker-compose.bot-server.yml restart
```

## Troubleshooting

### Agar Scripts Extract Nahi Ho Rahe

**Check file:**
```bash
# File verify karein
file missing-scripts.tar.gz
# Expected: gzip compressed data

# Contents check karein
tar -tzf missing-scripts.tar.gz
# Should show 4 files
```

**Agar file corrupt hai:**
- Phir se upload karein (Browser SSH se)
- Ya Server 1 se directly copy karein

### Agar Scripts Missing Hain

**Check tar contents:**
```bash
tar -tzf missing-scripts.tar.gz
```

**Expected output:**
```
setup-flexible-bots.sh
generate-flexible-bots.sh
auto-setup-bots.sh
update-compose-zak.py
```

**Agar files missing hain tar me:**
- Local machine se phir se package create karein
- Verify karein ki sab scripts include hain

## Verify Package Contents (Before Upload)

**Local machine par check karein:**

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"
tar -tzf missing-scripts.tar.gz
```

**Expected:**
```
setup-flexible-bots.sh
generate-flexible-bots.sh
auto-setup-bots.sh
update-compose-zak.py
```

## Summary

**Current:** File uploaded hai `/opt/zoom-headless-meeting` me  
**Fix:** Current directory se extract karein (not `~/`)  
**Commands:**
```bash
cd /opt/zoom-headless-meeting
tar -xzf missing-scripts.tar.gz
chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
```

Ye commands run karein, scripts extract ho jayengi! ✅


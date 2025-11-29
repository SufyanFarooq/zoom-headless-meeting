# Direct Update Server 1 - Simple Method

## Simple Solution: Direct Update in Project Folder

**Server 1 par Browser SSH me ye commands:**

### Option 1: Initialize Git in Project Folder

```bash
cd /opt/zoom-headless-meeting

# Initialize git (if not already)
git init

# Add remote
git remote add origin https://github.com/SufyanFarooq/zoom-headless-meeting.git

# Fetch latest
git fetch origin

# Pull latest code
git pull origin main

# Verify scripts updated
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3
# Should show: MEETING_ID="${7:-}"

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml
```

### Option 2: Direct File Copy (If Git Not Working)

**Agar git init nahi ho sakta, to files directly update karein:**

**Browser SSH me:**

```bash
cd /opt/zoom-headless-meeting

# Download files directly from GitHub
curl -o generate-flexible-bots.sh https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/generate-flexible-bots.sh
curl -o setup-flexible-bots.sh https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/setup-flexible-bots.sh
curl -o bot-server/api.js https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/bot-server/api.js
curl -o update-compose-zak.py https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/update-compose-zak.py

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Verify
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3

# Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml
```

### Option 3: Manual Copy-Paste (If GitHub Not Accessible)

**Browser SSH me nano editor se:**

```bash
cd /opt/zoom-headless-meeting

# Edit generate-flexible-bots.sh
nano generate-flexible-bots.sh
# Copy content from local file and paste
# Save: Ctrl+X, Y, Enter

# Edit setup-flexible-bots.sh
nano setup-flexible-bots.sh
# Copy content and paste

# Edit bot-server/api.js
nano bot-server/api.js
# Copy content and paste

# Edit update-compose-zak.py
nano update-compose-zak.py
# Copy content and paste

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
```

## After Update

```bash
# Remove old compose files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# Build Docker image (if missing)
docker build -t zoom-bot:latest . --platform linux/amd64

# Restart bot server
docker restart zoom-bot-server-api

# Verify
docker logs zoom-bot-server-api --tail 20
```

## Recommended: Option 2 (curl from GitHub)

**Sabse simple - Server 1 par Browser SSH me:**

```bash
cd /opt/zoom-headless-meeting

# Download updated files directly
curl -o generate-flexible-bots.sh https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/generate-flexible-bots.sh
curl -o setup-flexible-bots.sh https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/setup-flexible-bots.sh
curl -o bot-server/api.js https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/bot-server/api.js
curl -o update-compose-zak.py https://raw.githubusercontent.com/SufyanFarooq/zoom-headless-meeting/main/update-compose-zak.py

# Make executable
chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py

# Verify
grep -n "MEETING_ID" generate-flexible-bots.sh | head -3

# Remove old files
rm -f compose-50-bots.yaml compose-*-bots.yaml

# Restart bot server
docker restart zoom-bot-server-api
```

## Summary

**Best Method:** Option 2 (curl from GitHub)  
**No need for /tmp folder**  
**Direct update in project folder**

Ye method try karein - sabse simple hai! ✅


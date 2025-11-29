# Fix SSH Permission Denied - Alternative Solutions

## Problem
`scp` command se permission denied aa raha hai.

## Solution Options

### Option 1: Browser SSH se Manual Copy (Easiest)

**Step 1: Files ko local me readable format me save karein**

**Local machine par:**

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Create a simple text file with script content
cat generate-flexible-bots.sh > generate-flexible-bots.txt
cat setup-flexible-bots.sh > setup-flexible-bots.txt
cat bot-server/api.js > api.js.txt
cat update-compose-zak.py > update-compose-zak.py.txt
```

**Step 2: Browser SSH se copy-paste**

1. **Server 1 par Browser SSH kholo**
2. **File create karo:**
   ```bash
   cd /opt/zoom-headless-meeting
   
   # Generate script
   nano generate-flexible-bots.sh
   # Copy content from generate-flexible-bots.txt and paste
   # Save: Ctrl+X, Y, Enter
   
   # Setup script
   nano setup-flexible-bots.sh
   # Copy content from setup-flexible-bots.txt and paste
   # Save: Ctrl+X, Y, Enter
   
   # API file
   nano bot-server/api.js
   # Copy content from api.js.txt and paste
   # Save: Ctrl+X, Y, Enter
   
   # Python script
   nano update-compose-zak.py
   # Copy content from update-compose-zak.py.txt and paste
   # Save: Ctrl+X, Y, Enter
   ```

3. **Make executable:**
   ```bash
   chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
   ```

### Option 2: Git Clone on Server 1

**Server 1 par Browser SSH me:**

```bash
# Clone repo to temp location
cd /tmp
git clone https://github.com/SufyanFarooq/zoom-headless-meeting.git

# Copy updated files
cp zoom-headless-meeting/generate-flexible-bots.sh /opt/zoom-headless-meeting/
cp zoom-headless-meeting/setup-flexible-bots.sh /opt/zoom-headless-meeting/
cp zoom-headless-meeting/bot-server/api.js /opt/zoom-headless-meeting/bot-server/
cp zoom-headless-meeting/update-compose-zak.py /opt/zoom-headless-meeting/

# Make executable
chmod +x /opt/zoom-headless-meeting/*.sh
chmod +x /opt/zoom-headless-meeting/update-compose-zak.py

# Cleanup
rm -rf /tmp/zoom-headless-meeting
```

### Option 3: Setup SSH Key (Long-term)

**Local machine par:**

```bash
# Generate SSH key (if not exists)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy public key
cat ~/.ssh/id_rsa.pub

# Server 1 par add karein (Browser SSH me):
# mkdir -p ~/.ssh
# echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
# chmod 600 ~/.ssh/authorized_keys
# chmod 700 ~/.ssh
```

### Option 4: Use tar.gz with Browser SSH Upload

**Local machine par:**

```bash
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"
tar -czf updated-scripts.tar.gz \
  generate-flexible-bots.sh \
  setup-flexible-bots.sh \
  bot-server/api.js \
  update-compose-zak.py
```

**Browser SSH se:**
1. Upload `updated-scripts.tar.gz` file
2. Extract:
   ```bash
   cd /opt/zoom-headless-meeting
   tar -xzf /tmp/updated-scripts.tar.gz
   chmod +x generate-flexible-bots.sh setup-flexible-bots.sh update-compose-zak.py
   ```

## Recommended: Option 2 (Git Clone)

**Server 1 par Browser SSH me ye commands:**

```bash
# Clone repo
cd /tmp
git clone https://github.com/SufyanFarooq/zoom-headless-meeting.git

# Copy files
cp zoom-headless-meeting/generate-flexible-bots.sh /opt/zoom-headless-meeting/
cp zoom-headless-meeting/setup-flexible-bots.sh /opt/zoom-headless-meeting/
cp zoom-headless-meeting/bot-server/api.js /opt/zoom-headless-meeting/bot-server/
cp zoom-headless-meeting/update-compose-zak.py /opt/zoom-headless-meeting/

# Make executable
chmod +x /opt/zoom-headless-meeting/*.sh
chmod +x /opt/zoom-headless-meeting/update-compose-zak.py

# Verify
grep -n "MEETING_ID" /opt/zoom-headless-meeting/generate-flexible-bots.sh | head -3

# Cleanup
rm -rf /tmp/zoom-headless-meeting

# Remove old compose files
cd /opt/zoom-headless-meeting
rm -f compose-50-bots.yaml compose-*-bots.yaml
```

## Summary

**Easiest:** Option 2 (Git Clone on Server 1)  
**Quick:** Option 4 (Browser SSH Upload tar.gz)  
**Manual:** Option 1 (Copy-paste via nano)

Ye options try karein!


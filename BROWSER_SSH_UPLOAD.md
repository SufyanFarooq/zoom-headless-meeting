# Browser SSH se Package Upload - Complete Guide

## Method 1: Local Machine se Create aur Upload (Easiest) ⭐

### Step 1: Local Machine par Package Create Karein

```bash
# Local machine par (Mac/Windows/Linux)
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Package create karein
./scripts/prepare-bot-server-package.sh

# Ye create karega: bot-server-only.tar.gz
ls -lh bot-server-only.tar.gz
```

### Step 2: GCP Browser SSH Open Karein

1. [GCP Console](https://console.cloud.google.com) par jayein
2. **Compute Engine → VM instances**
3. `zoom-bots-server` ke saamne **"SSH"** button click karein
4. Browser terminal open hoga

### Step 3: Browser SSH me Upload Karein

**Option A: Drag & Drop (Easiest)**

1. Browser SSH terminal me, top-right corner me **"⚙️ Settings"** icon click karein
2. **"Upload file"** option select karein
3. Local machine se `bot-server-only.tar.gz` file drag & drop karein
4. File `/home/YOUR_USERNAME/` me upload ho jayegi

**Option B: Using Upload Button**

1. Browser SSH terminal me, top-right corner me **"⚙️"** icon click karein
2. **"Upload file"** click karein
3. File browser se `bot-server-only.tar.gz` select karein
4. Upload ho jayega

**Option C: Using gcloud (if installed locally)**

```bash
# Local machine se directly upload
gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c
```

### Step 4: Server 2 par Setup Karein

Browser SSH terminal me:

```bash
# Package move karein
sudo mv ~/bot-server-only.tar.gz /opt/

# Extract karein
cd /opt
sudo tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting

# Permissions fix karein
sudo chown -R $USER:$USER /opt/zoom-headless-meeting

# .env file create karein
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Docker install (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Start bot server
docker compose -f docker-compose.bot-server.yml up -d
```

---

## Method 2: Server 1 se Download, Phir Upload

### Step 1: Server 1 se Package Download Karein

**Option A: Using SCP (Local Machine se)**

```bash
# Local machine se Server 1 se download
scp user@SERVER1_IP:/opt/zoom-headless-meeting/bot-server-only.tar.gz ./

# Ya Server 1 par package create karein
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting
./scripts/prepare-bot-server-package.sh
exit

# Phir download karein
scp user@SERVER1_IP:/opt/zoom-headless-meeting/bot-server-only.tar.gz ./
```

**Option B: Using Browser (Server 1 par)**

1. Server 1 par browser SSH open karein
2. Package create karein:
   ```bash
   cd /opt/zoom-headless-meeting
   ./scripts/prepare-bot-server-package.sh
   ```
3. Browser SSH me **"Download file"** button se download karein

### Step 2: Local Machine par Package Mil Gaya

Ab local machine par `bot-server-only.tar.gz` hai.

### Step 3: GCP Server 2 par Upload Karein

1. GCP Console → Browser SSH open karein
2. **"Upload file"** se upload karein (Method 1 ke Step 3 dekhein)

---

## Method 3: Cloud Storage Use Karein (Best for Large Files)

### Step 1: Server 1 se Cloud Storage Upload

```bash
# Server 1 par
cd /opt/zoom-headless-meeting
./scripts/prepare-bot-server-package.sh

# Cloud Storage bucket create karein (if not exists)
gsutil mb gs://zoom-bots-packages/

# Upload karein
gsutil cp bot-server-only.tar.gz gs://zoom-bots-packages/
```

### Step 2: Server 2 par Download Karein

Browser SSH me:

```bash
# Download from Cloud Storage
gsutil cp gs://zoom-bots-packages/bot-server-only.tar.gz /opt/

# Extract
cd /opt
tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting
```

---

## Method 4: Direct Server 1 se Server 2 Transfer

### Option A: Server 1 se Direct Copy

```bash
# Server 1 par browser SSH
cd /opt/zoom-headless-meeting
./scripts/prepare-bot-server-package.sh

# Direct copy to Server 2
scp bot-server-only.tar.gz YOUR_USERNAME@35.227.36.166:/opt/
```

**Note**: Agar Server 1 se Server 2 direct SSH allowed hai.

### Option B: Using wget/curl (if Server 1 has public URL)

```bash
# Server 1 par web server start karein (temporary)
cd /opt/zoom-headless-meeting
python3 -m http.server 8000

# Server 2 par download karein
wget http://SERVER1_IP:8000/bot-server-only.tar.gz
```

---

## Complete Step-by-Step (Recommended)

### On Local Machine:

```bash
# 1. Package create karein
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"
./scripts/prepare-bot-server-package.sh

# 2. Package size check karein
ls -lh bot-server-only.tar.gz
# Expected: ~50-200MB (depends on build size)
```

### On GCP Browser SSH:

1. **GCP Console** → **Compute Engine** → **VM instances**
2. `zoom-bots-server` ke saamne **"SSH"** click karein
3. Browser terminal me:

```bash
# 3. Upload directory prepare karein
sudo mkdir -p /opt
sudo chown $USER:$USER /opt
```

4. Browser SSH me **"⚙️ Settings"** → **"Upload file"**
5. Local machine se `bot-server-only.tar.gz` select karein
6. Upload ho jayega `/home/YOUR_USERNAME/` me

7. Browser terminal me continue:

```bash
# 4. Move to /opt
mv ~/bot-server-only.tar.gz /opt/

# 5. Extract
cd /opt
tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting

# 6. Verify files
ls -la
# Should see: bot-server/, build/, lib/, videos/, etc.

# 7. Create .env
cat > .env << 'EOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# 8. Install Docker (if needed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 9. Start bot server
docker compose -f docker-compose.bot-server.yml up -d

# 10. Verify
curl http://localhost:3001/health
```

---

## Troubleshooting

### Upload File Button Nahi Dikhta?

1. Browser SSH terminal me **"⚙️"** icon check karein (top-right)
2. Agar nahi dikhta, try:
   - Browser refresh karein
   - Different browser try karein (Chrome recommended)
   - Incognito mode try karein

### File Upload Failed?

**Option 1: Use gcloud (if installed)**
```bash
# Local machine se
gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c
```

**Option 2: Use Cloud Storage**
```bash
# Upload to Cloud Storage
gsutil cp bot-server-only.tar.gz gs://your-bucket/

# Download on Server 2
gsutil cp gs://your-bucket/bot-server-only.tar.gz /opt/
```

**Option 3: Split Large File**
```bash
# Split file (if > 100MB)
split -b 50M bot-server-only.tar.gz bot-server-only.tar.gz.part

# Upload parts separately
# Then combine on Server 2:
cat bot-server-only.tar.gz.part* > bot-server-only.tar.gz
```

### Permission Denied?

```bash
# Fix permissions
sudo chown -R $USER:$USER /opt/zoom-headless-meeting
sudo chmod +x /opt/zoom-headless-meeting/bin/*.sh
```

---

## Quick Reference

### Local Machine se Upload:

1. ✅ Package create: `./scripts/prepare-bot-server-package.sh`
2. ✅ GCP Browser SSH open karein
3. ✅ "Upload file" button click karein
4. ✅ `bot-server-only.tar.gz` select karein
5. ✅ Upload complete!

### Alternative Commands:

```bash
# Using gcloud (if installed)
gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c

# Using Cloud Storage
gsutil cp bot-server-only.tar.gz gs://your-bucket/
# Then on Server 2:
gsutil cp gs://your-bucket/bot-server-only.tar.gz /opt/
```

---

## Summary

**Best Method:**
1. ✅ Local machine par package create karein
2. ✅ GCP Browser SSH me "Upload file" se upload karein
3. ✅ Extract aur setup karein

**Package Location:**
- Local: `bot-server-only.tar.gz`
- Server 2: `/opt/bot-server-only.tar.gz` (after upload)

**Size Check:**
- Package size: ~50-200MB (depends on build/)
- Browser upload limit: Usually 1GB+ (sufficient)


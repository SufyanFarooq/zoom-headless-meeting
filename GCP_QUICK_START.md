# GCP Server 2 - Quick Start Guide

## Your GCP VM Details
- **Name**: `zoom-bots-server`
- **External IP**: `35.227.36.166`
- **Internal IP**: `10.142.0.2`
- **Zone**: `us-east1-c`
- **Status**: ✅ Running

## Method 1: Using gcloud CLI (Easiest) ⭐

### Step 1: Install gcloud (if not installed)
```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Step 2: Login and Setup
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: SSH to Server 2
```bash
gcloud compute ssh zoom-bots-server --zone=us-east1-c
```
**That's it!** gcloud automatically handles SSH keys.

### Step 4: Copy Package from Server 1
**On Server 1:**
```bash
cd /opt/zoom-headless-meeting
./scripts/prepare-bot-server-package.sh
```

**Copy to Server 2:**
```bash
# From Server 1, copy to GCP
gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c
```

### Step 5: Setup on Server 2
```bash
# SSH to Server 2 (if not already)
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Extract package
cd /opt
tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting

# Create .env
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Logout and login again

# Start bot server
docker compose -f docker-compose.bot-server.yml up -d

# Verify
curl http://localhost:3001/health
```

---

## Method 2: Browser SSH (No Setup Needed)

### Step 1: SSH via Browser
1. Go to [GCP Console](https://console.cloud.google.com)
2. Navigate to: **Compute Engine → VM instances**
3. Click **"SSH"** button next to `zoom-bots-server`
4. Browser-based terminal opens

### Step 2: Upload Package
**Option A: Using wget/curl (if Server 1 has public URL)**
```bash
# On Server 2 (browser SSH)
cd /opt
wget http://SERVER1_IP/bot-server-only.tar.gz
```

**Option B: Using Cloud Storage**
```bash
# On Server 1
gsutil cp bot-server-only.tar.gz gs://your-bucket/

# On Server 2
gsutil cp gs://your-bucket/bot-server-only.tar.gz /opt/
```

**Option C: Manual Upload**
1. Download package from Server 1 to your local machine
2. In browser SSH, click **"Upload file"** button
3. Select `bot-server-only.tar.gz`
4. Upload to `/opt/`

---

## Method 3: Direct SSH with Key

### Step 1: Generate SSH Key
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/gcp_zoom_bots -N ""
```

### Step 2: Add Key to GCP VM
1. Go to GCP Console → VM instances
2. Click on `zoom-bots-server`
3. Click **"Edit"**
4. Scroll to **"SSH Keys"**
5. Click **"Add Item"**
6. Paste public key:
   ```bash
   cat ~/.ssh/gcp_zoom_bots.pub
   ```
7. Click **"Save"**

### Step 3: SSH and Copy
```bash
# SSH to Server 2
ssh -i ~/.ssh/gcp_zoom_bots YOUR_USERNAME@35.227.36.166

# Copy package from Server 1
scp -i ~/.ssh/gcp_zoom_bots user@SERVER1_IP:/path/to/bot-server-only.tar.gz /opt/
```

---

## Quick Commands Reference

### SSH to Server 2
```bash
# Method 1: gcloud (easiest)
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Method 2: Direct SSH
ssh YOUR_USERNAME@35.227.36.166
```

### Copy Files
```bash
# Using gcloud
gcloud compute scp FILE zoom-bots-server:/opt/ --zone=us-east1-c

# Using scp
scp FILE YOUR_USERNAME@35.227.36.166:/opt/
```

### Check VM Status
```bash
gcloud compute instances describe zoom-bots-server --zone=us-east1-c
```

### Get External IP
```bash
gcloud compute instances describe zoom-bots-server --zone=us-east1-c \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

---

## Firewall Setup

Allow port 3001 for bot server:

```bash
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

Or via Console:
1. **VPC Network → Firewall**
2. **Create Firewall Rule**
3. Name: `allow-bot-server`
4. Port: `tcp:3001`
5. **Create**

---

## Register Server 2

After Server 2 is running:

```bash
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://35.227.36.166:3001",
    "capacity": 10,
    "priority": 2
  }'
```

---

## Troubleshooting

### Can't SSH?
1. **Use browser SSH** (always works)
2. Check firewall allows port 22
3. Check VM is running

### Can't copy files?
1. Use **Cloud Storage** (gsutil)
2. Use **browser upload**
3. Use **wget** if Server 1 has public URL

### Docker issues?
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again
```

---

## Summary

**Easiest Method:**
1. Install gcloud: `brew install google-cloud-sdk`
2. SSH: `gcloud compute ssh zoom-bots-server --zone=us-east1-c`
3. Copy: `gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c`
4. Setup on Server 2
5. Register on Server 1

**No gcloud?**
- Use browser SSH from GCP Console
- Upload files via browser or Cloud Storage


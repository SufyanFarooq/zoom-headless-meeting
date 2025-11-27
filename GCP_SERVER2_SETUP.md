# GCP Server 2 Setup Guide

## Overview

This guide helps you setup Server 2 on Google Cloud Platform (GCP) and copy the bot-server package from Server 1.

## Prerequisites

- GCP VM instance running (e.g., `zoom-bots-server`)
- External IP address (e.g., `35.227.36.166`)
- Access to GCP Console
- Server 1 has bot-server package ready

## Method 1: Using gcloud CLI (Recommended)

### Step 1: Install gcloud CLI

```bash
# On macOS
brew install google-cloud-sdk

# On Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize
gcloud init
```

### Step 2: Authenticate

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: Generate SSH Key (if needed)

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/gcp_zoom_bots -N "" -C "zoom-bots-server2"

# View public key
cat ~/.ssh/gcp_zoom_bots.pub
```

### Step 4: Add SSH Key to GCP VM

**Option A: Using gcloud (Automatic)**
```bash
# gcloud automatically manages SSH keys
gcloud compute ssh zoom-bots-server --zone=us-east1-c
```

**Option B: Manual (via GCP Console)**
1. Go to GCP Console → Compute Engine → VM instances
2. Click on your VM: `zoom-bots-server`
3. Click **"Edit"** button
4. Scroll to **"SSH Keys"** section
5. Click **"Add Item"**
6. Paste your public key:
   ```bash
   cat ~/.ssh/gcp_zoom_bots.pub
   ```
7. Click **"Save"**

### Step 5: Test SSH Connection

```bash
# Method 1: Using gcloud (easiest)
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Method 2: Direct SSH
ssh -i ~/.ssh/gcp_zoom_bots YOUR_USERNAME@35.227.36.166
```

### Step 6: Copy Package from Server 1

**On Server 1:**
```bash
# Create package
cd /opt/zoom-headless-meeting
./scripts/prepare-bot-server-package.sh

# This creates: bot-server-only.tar.gz
```

**Copy to GCP Server 2:**
```bash
# Using gcloud compute scp
gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c

# Or using regular scp
scp -i ~/.ssh/gcp_zoom_bots bot-server-only.tar.gz YOUR_USERNAME@35.227.36.166:/opt/
```

### Step 7: Setup on Server 2

```bash
# SSH to Server 2
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Extract package
cd /opt
tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting

# Create .env file
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Logout and login again for docker group to take effect

# Start bot server
docker compose -f docker-compose.bot-server.yml up -d

# Verify
curl http://localhost:3001/health
```

## Method 2: Using Automated Script

```bash
# On Server 1
cd /opt/zoom-headless-meeting
chmod +x scripts/setup-gcp-server2.sh
./scripts/setup-gcp-server2.sh
```

The script will:
1. Generate SSH key (if needed)
2. Guide you to add SSH key to GCP
3. Test SSH connection
4. Copy package to Server 2
5. Extract and setup on Server 2

## Method 3: Manual Setup (No gcloud)

### Step 1: Get SSH Access

1. **Via GCP Console:**
   - Go to VM instances
   - Click **"SSH"** button next to your VM
   - This opens browser-based SSH

2. **Via Password (if enabled):**
   ```bash
   ssh YOUR_USERNAME@35.227.36.166
   # Enter password when prompted
   ```

3. **Via SSH Key:**
   - Generate key: `ssh-keygen -t rsa -b 4096`
   - Add public key to GCP VM metadata
   - Connect: `ssh -i ~/.ssh/your_key YOUR_USERNAME@35.227.36.166`

### Step 2: Copy Files

**Option A: Using SCP**
```bash
# From Server 1
scp bot-server-only.tar.gz YOUR_USERNAME@35.227.36.166:/opt/
```

**Option B: Using rsync**
```bash
# From Server 1
rsync -avz -e ssh bot-server-only.tar.gz YOUR_USERNAME@35.227.36.166:/opt/
```

**Option C: Using GCP Console**
1. Use browser-based SSH
2. Create file upload script
3. Upload via browser

**Option D: Using Cloud Storage**
```bash
# Upload to GCS from Server 1
gsutil cp bot-server-only.tar.gz gs://your-bucket/

# Download on Server 2
gsutil cp gs://your-bucket/bot-server-only.tar.gz /opt/
```

## GCP Firewall Rules

Make sure firewall allows:
- **Port 22** (SSH) - Usually enabled by default
- **Port 3001** (Bot Server API) - Need to add

```bash
# Add firewall rule for bot server
gcloud compute firewall-rules create allow-bot-server \
  --allow tcp:3001 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow bot server API"
```

Or via Console:
1. Go to **VPC Network → Firewall**
2. Click **"Create Firewall Rule"**
3. Name: `allow-bot-server`
4. Targets: `All instances in the network`
5. Source IP ranges: `0.0.0.0/0` (or specific IPs)
6. Protocols and ports: `tcp:3001`
7. Click **"Create"**

## Register Server 2

After Server 2 is running:

```bash
# On Server 1 (or any machine with API access)
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://35.227.36.166:3001",
    "capacity": 10,
    "priority": 2
  }'
```

## Troubleshooting

### SSH Connection Failed

1. **Check VM is running:**
   ```bash
   gcloud compute instances list
   ```

2. **Check firewall rules:**
   ```bash
   gcloud compute firewall-rules list --filter="name~ssh"
   ```

3. **Check SSH key:**
   ```bash
   # View public key
   cat ~/.ssh/gcp_zoom_bots.pub
   
   # Verify it's added to VM metadata
   gcloud compute instances describe zoom-bots-server --zone=us-east1-c
   ```

4. **Try browser SSH:**
   - Use GCP Console → SSH button
   - This always works if VM is running

### Package Copy Failed

1. **Check disk space:**
   ```bash
   df -h
   ```

2. **Check permissions:**
   ```bash
   ls -la /opt/
   sudo chown $USER:$USER /opt/
   ```

3. **Use alternative method:**
   - Cloud Storage
   - Browser upload
   - Direct download from Server 1

### Docker Not Working

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again
exit
# SSH again

# Test Docker
docker ps
```

### Bot Server Not Starting

```bash
# Check logs
docker compose -f docker-compose.bot-server.yml logs

# Check if port is available
sudo netstat -tulpn | grep 3001

# Check Docker socket
ls -la /var/run/docker.sock
```

## Quick Reference

### SSH Commands

```bash
# Using gcloud
gcloud compute ssh zoom-bots-server --zone=us-east1-c

# Direct SSH
ssh -i ~/.ssh/gcp_zoom_bots YOUR_USERNAME@35.227.36.166
```

### Copy Files

```bash
# Using gcloud
gcloud compute scp FILE zoom-bots-server:/path/ --zone=us-east1-c

# Using scp
scp -i ~/.ssh/gcp_zoom_bots FILE YOUR_USERNAME@35.227.36.166:/path/
```

### VM Info

```bash
# List VMs
gcloud compute instances list

# Get VM details
gcloud compute instances describe zoom-bots-server --zone=us-east1-c

# Get external IP
gcloud compute instances describe zoom-bots-server --zone=us-east1-c --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

## Summary

**Quick Setup:**
1. Install gcloud CLI
2. Run: `gcloud compute ssh zoom-bots-server --zone=us-east1-c`
3. Copy package: `gcloud compute scp bot-server-only.tar.gz zoom-bots-server:/opt/ --zone=us-east1-c`
4. Extract and setup on Server 2
5. Register on Server 1

**Your GCP VM:**
- Name: `zoom-bots-server`
- External IP: `35.227.36.166`
- Zone: `us-east1-c`


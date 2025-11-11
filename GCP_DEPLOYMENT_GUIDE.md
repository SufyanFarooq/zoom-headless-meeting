# Google Cloud Platform (GCP) Deployment Guide - 100 Bots

## Overview

GCP provides $300 free credits for 90 days, perfect for testing 100 bots. This guide covers complete setup on GCP.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Create GCP Account](#step-1-create-gcp-account)
3. [Step 2: Create VM Instance](#step-2-create-vm-instance)
4. [Step 3: Connect to Instance](#step-3-connect-to-instance)
5. [Step 4: Install Docker](#step-4-install-docker)
6. [Step 5: Deploy Bots](#step-5-deploy-bots)
7. [Step 6: Monitor & Manage](#step-6-monitor--manage)
8. [Cost Management](#cost-management)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Gmail account (for GCP signup)
- Credit card (for verification, won't be charged if you stay within free tier)
- Basic knowledge of Linux commands

---

## Step 1: Create GCP Account

### 1.1 Sign Up

1. **Go to:** https://cloud.google.com/
2. **Click:** "Get started for free"
3. **Sign in** with your Google account
4. **Fill details:**
   - Country
   - Account type (Individual or Business)
   - Accept terms

### 1.2 Free Trial Activation

1. **Add payment method:**
   - Credit card required (for verification)
   - **Won't be charged** if you stay within free tier
   - Can set billing alerts

2. **Get $300 credits:**
   - Valid for 90 days
   - Can use for any GCP service
   - Enough for 2 months of testing

3. **Verify account:**
   - Check email for verification
   - Complete account setup

---

## Step 2: Create VM Instance

### 2.1 Navigate to Compute Engine

1. **Go to:** https://console.cloud.google.com/
2. **Select project** (or create new)
3. **Enable Compute Engine API:**
   - Go to "APIs & Services" → "Library"
   - Search "Compute Engine API"
   - Click "Enable"

### 2.2 Create VM Instance

1. **Go to:** Compute Engine → VM instances
2. **Click:** "Create Instance"

3. **Configure Instance:**

   **Name:** `zoom-bots-server`
   
   **Region:** 
   - Choose closest to you
   - Recommended: `us-east1` (N. Virginia) or `us-central1`
   
   **Zone:** Any (e.g., `us-east1-b`)
   
   **Machine Configuration:**
   - **Machine family:** General-purpose
   - **Machine type:** 
     - For 100 bots: `n1-standard-4` (4 vCPU, 15GB RAM)
     - Cost: ~$150/month (free with $300 credits for 2 months)
     - Or: `e2-standard-4` (4 vCPU, 16GB RAM) - newer, similar cost
   
   **Boot disk:**
   - **OS:** Ubuntu
   - **Version:** Ubuntu 22.04 LTS
   - **Size:** 30GB (default is fine)
   - **Disk type:** Standard persistent disk
   
   **Firewall:**
   - ✅ Allow HTTP traffic (optional)
   - ✅ Allow HTTPS traffic (optional)
   - SSH will be allowed automatically

4. **Click:** "Create"

### 2.3 Instance Specifications

| Machine Type | vCPU | RAM | Cost/Month | Max Bots |
|--------------|------|-----|------------|----------|
| n1-standard-2 | 2 | 7.5GB | ~$75 | 40-50 |
| n1-standard-4 | 4 | 15GB | ~$150 | 80-100 |
| e2-standard-4 | 4 | 16GB | ~$150 | 80-100 |
| n1-standard-8 | 8 | 30GB | ~$300 | 150+ |

**For 100 bots:** Use `n1-standard-4` or `e2-standard-4`

---

## Step 3: Connect to Instance

### 3.1 Using Browser SSH (Easiest)

1. **Go to:** Compute Engine → VM instances
2. **Click:** SSH button next to your instance
3. **Browser window opens** with terminal

### 3.2 Using gcloud CLI (Recommended)

**Install gcloud CLI on your local machine:**

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows
# Download installer from: https://cloud.google.com/sdk/docs/install
```

**Authenticate:**

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

**Connect:**

```bash
gcloud compute ssh zoom-bots-server --zone=us-east1-b
```

### 3.3 Using Regular SSH

1. **Create SSH key:**
```bash
# On your local machine
ssh-keygen -t rsa -f ~/.ssh/gcp_key -C "your-email@gmail.com"
```

2. **Add key to GCP:**
   - Go to: Compute Engine → Metadata → SSH Keys
   - Click "Add Item"
   - Paste public key: `cat ~/.ssh/gcp_key.pub`

3. **Connect:**
```bash
ssh -i ~/.ssh/gcp_key your-username@EXTERNAL_IP
```

---

## Step 4: Install Docker

### 4.1 Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 4.2 Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes
exit
```

### 4.3 Verify Installation

```bash
# Reconnect to instance
# Then verify:
docker --version
docker-compose --version
docker run hello-world
```

### 4.4 Configure Docker (Optional)

```bash
# Configure Docker logging
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

---

## Step 5: Deploy Bots

### 5.1 Transfer Code

**Option A: Using Git (Recommended)**

```bash
# On GCP instance
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

**Option B: Using gcloud scp**

```bash
# On your local machine
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b
```

**Option C: Using rsync**

```bash
# On your local machine
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b
```

### 5.2 Generate Compose File

```bash
# On GCP instance
cd ~/meetingsdk-headless-linux-sample
./generate-bots.sh 100
```

### 5.3 Build Images

```bash
# Build all images (takes 15-20 minutes first time)
docker compose -f compose-50-bots.yaml build

# Or build in parallel (faster)
docker compose -f compose-50-bots.yaml build --parallel
```

### 5.4 Start Bots

```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker compose -f compose-50-bots.yaml ps

# View logs
docker compose -f compose-50-bots.yaml logs -f
```

### 5.5 Using Automated Script

```bash
# Use the free trial setup script
./FREE_TRIAL_SETUP.sh 100

# Or use regular deploy script
./deploy.sh 100
```

---

## Step 6: Monitor & Manage

### 6.1 Check Bot Status

```bash
# List running containers
docker ps | grep zoom-bot

# Count running bots
docker ps | grep zoom-bot | wc -l

# Check resource usage
docker stats --no-stream | grep zoom-bot

# View logs for specific bot
docker logs zoom-bot-1 -f

# View all logs
docker compose -f compose-50-bots.yaml logs -f
```

### 6.2 GCP Console Monitoring

1. **Go to:** Compute Engine → VM instances
2. **Click:** Your instance name
3. **View:**
   - CPU usage
   - Memory usage
   - Network traffic
   - Disk I/O

### 6.3 Stop/Start Instance

**Stop instance (saves money when not in use):**

```bash
# Via console: Click "Stop" button
# Via CLI:
gcloud compute instances stop zoom-bots-server --zone=us-east1-b
```

**Start instance:**

```bash
# Via console: Click "Start" button
# Via CLI:
gcloud compute instances start zoom-bots-server --zone=us-east1-b
```

**Note:** Stopping instance **stops billing** for compute, but you still pay for disk storage (~$3/month for 30GB).

---

## Cost Management

### 6.1 Free Tier Limits

- **$300 credits** for 90 days
- **Always Free:** 
  - 1 f1-micro instance per month (not enough for bots)
  - 30GB disk storage
  - 5GB snapshot storage

### 6.2 Estimated Costs

**For 100 bots (n1-standard-4):**

- **Instance:** ~$150/month
- **Disk (30GB):** ~$3/month
- **Network:** ~$5-10/month (minimal for bots)
- **Total:** ~$160/month
- **With $300 credits:** Free for ~2 months

### 6.3 Set Budget Alerts

1. **Go to:** Billing → Budgets & alerts
2. **Create budget:**
   - Amount: $50 (or your limit)
   - Alert at: 50%, 90%, 100%
3. **Get email alerts** when approaching limit

### 6.4 Cost Optimization Tips

1. **Stop instance when not in use:**
   ```bash
   gcloud compute instances stop zoom-bots-server --zone=us-east1-b
   ```

2. **Use preemptible instances** (60-80% cheaper, but can be terminated):
   - When creating instance, check "Preemptible"
   - Good for testing, not production

3. **Delete instance when done:**
   - Saves compute costs
   - Keep disk if you want to reuse

---

## Troubleshooting

### Connection Issues

```bash
# Check if instance is running
gcloud compute instances list

# Check firewall rules
gcloud compute firewall-rules list

# Test connectivity
ping EXTERNAL_IP
```

### Docker Issues

```bash
# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker.service -f
```

### Resource Issues

```bash
# Check memory
free -h

# Check CPU
top

# Check disk
df -h

# Check Docker disk usage
docker system df
```

### Bot-Specific Issues

```bash
# Check specific bot logs
docker logs zoom-bot-1 --tail 100

# Check all bot logs for errors
docker compose -f compose-50-bots.yaml logs | grep -i error

# Restart failed bots
docker compose -f compose-50-bots.yaml restart bot-1
```

---

## Quick Reference Commands

### Instance Management

```bash
# List instances
gcloud compute instances list

# Start instance
gcloud compute instances start zoom-bots-server --zone=us-east1-b

# Stop instance
gcloud compute instances stop zoom-bots-server --zone=us-east1-b

# Delete instance
gcloud compute instances delete zoom-bots-server --zone=us-east1-b

# Get external IP
gcloud compute instances describe zoom-bots-server --zone=us-east1-b --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

### Bot Management

```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Stop all bots
docker compose -f compose-50-bots.yaml down

# Restart all bots
docker compose -f compose-50-bots.yaml restart

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Check status
docker compose -f compose-50-bots.yaml ps
```

---

## Step-by-Step Quick Start

### Complete Setup in One Go

```bash
# 1. Connect to instance
gcloud compute ssh zoom-bots-server --zone=us-east1-b

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
exit

# 3. Reconnect
gcloud compute ssh zoom-bots-server --zone=us-east1-b

# 4. Transfer code (from local machine)
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b

# 5. Deploy (on instance)
cd ~/meetingsdk-headless-linux-sample
./generate-bots.sh 100
./deploy.sh 100

# 6. Monitor
docker compose -f compose-50-bots.yaml logs -f
```

---

## Best Practices

### 1. Use Startup Script

When creating instance, add **Startup script**:

```bash
#!/bin/bash
cd /home/ubuntu
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
chmod +x deploy.sh
./deploy.sh 100
```

### 2. Set Up Monitoring

```bash
# Install monitoring tools
sudo apt-get install htop iotop -y

# Monitor resources
htop
```

### 3. Regular Backups

```bash
# Create snapshot of disk
gcloud compute disks snapshot DISK_NAME --snapshot-name=snapshot-$(date +%Y%m%d) --zone=us-east1-b
```

### 4. Clean Up

```bash
# Stop instance when not in use
gcloud compute instances stop zoom-bots-server --zone=us-east1-b

# Delete instance when done (saves money)
gcloud compute instances delete zoom-bots-server --zone=us-east1-b
```

---

## Cost Breakdown Example

**Scenario: Testing 100 bots for 1 month**

- **Instance (n1-standard-4):** $150
- **Disk (30GB):** $3
- **Network:** $5
- **Total:** $158/month
- **With $300 credits:** Free for ~2 months

**After credits expire:**
- Stop instance when not in use
- Use preemptible instances (60% cheaper)
- Or switch to smaller instance for fewer bots

---

## Next Steps

1. ✅ Create GCP account and get $300 credits
2. ✅ Create VM instance (n1-standard-4)
3. ✅ Install Docker
4. ✅ Deploy 100 bots
5. ✅ Monitor and verify bots are working
6. ✅ Set budget alerts to avoid surprise charges

---

## Support

If you encounter issues:
1. Check GCP documentation: https://cloud.google.com/docs
2. Check instance logs in GCP Console
3. Review this guide's troubleshooting section
4. Check Docker logs: `docker compose -f compose-50-bots.yaml logs`


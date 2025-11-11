# Server Deployment Guide - Zoom Bots

## Overview

This guide covers deploying the Zoom bots to a server (AWS EC2, DigitalOcean, etc.) using Docker. Server deployment can help resolve network throttling issues and provide better stability.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Option 1: AWS EC2 Deployment](#option-1-aws-ec2-deployment)
3. [Option 2: DigitalOcean Droplet](#option-2-digitalocean-droplet)
4. [Option 3: Any Linux Server](#option-3-any-linux-server)
5. [Docker Setup](#docker-setup)
6. [Deploying Bots](#deploying-bots)
7. [Monitoring & Management](#monitoring--management)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Server with:
  - Ubuntu 20.04+ or similar Linux distribution
  - Minimum 4GB RAM (8GB+ recommended for 50 bots)
  - Minimum 2 CPU cores (4+ recommended)
  - 20GB+ free disk space
  - Docker and Docker Compose installed
  - SSH access

---

## Option 1: AWS EC2 Deployment

### Step 1: Launch EC2 Instance

1. **Go to AWS Console** → EC2 → Launch Instance

2. **Choose Instance Type:**
   - For 10 bots: `t3.medium` (2 vCPU, 4GB RAM)
   - For 50 bots: `t3.large` (2 vCPU, 8GB RAM) or `t3.xlarge` (4 vCPU, 16GB RAM)
   - For 100+ bots: `t3.2xlarge` (8 vCPU, 32GB RAM)

3. **Configure Instance:**
   - **AMI:** Ubuntu Server 22.04 LTS
   - **Instance Type:** Based on bot count (see above)
   - **Key Pair:** Create or select existing key pair
   - **Network:** Default VPC (or create new)
   - **Security Group:** 
     - SSH (port 22) from your IP
     - Optionally: HTTP/HTTPS if needed

4. **Storage:** 30GB+ (gp3 recommended)

5. **Launch Instance**

### Step 2: Connect to EC2

```bash
# Replace with your key and instance IP
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### Step 3: Install Docker

```bash
# Update system
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes
exit
```

### Step 4: Transfer Code to Server

**Option A: Using Git (Recommended)**

```bash
# On server
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

**Option B: Using SCP**

```bash
# On your local machine
scp -i your-key.pem -r /path/to/meetingsdk-headless-linux-sample ubuntu@your-ec2-ip:~/
```

**Option C: Using rsync**

```bash
# On your local machine
rsync -avz -e "ssh -i your-key.pem" /path/to/meetingsdk-headless-linux-sample/ ubuntu@your-ec2-ip:~/meetingsdk-headless-linux-sample/
```

---

## Option 2: DigitalOcean Droplet

### Step 1: Create Droplet

1. **Go to DigitalOcean** → Create → Droplets

2. **Choose Configuration:**
   - **Image:** Ubuntu 22.04
   - **Plan:** 
     - 10 bots: Regular ($12/month - 2GB RAM)
     - 50 bots: Regular ($24/month - 4GB RAM)
     - 100+ bots: Regular ($48/month - 8GB RAM)
   - **Region:** Choose closest to Zoom servers (US East recommended)
   - **Authentication:** SSH keys (recommended) or password

3. **Create Droplet**

### Step 2: Connect and Setup

```bash
# Connect to droplet
ssh root@your-droplet-ip

# Install Docker (same as EC2 steps above)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

---

## Option 3: Any Linux Server

### Requirements

- Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / RHEL 8+
- Root or sudo access
- Internet connectivity

### Install Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# CentOS/RHEL
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

## Docker Setup

### Verify Installation

```bash
# Check Docker
docker --version
docker-compose --version

# Test Docker
docker run hello-world
```

### Configure Docker (Optional)

```bash
# Increase Docker log size (prevent disk full)
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

## Deploying Bots

### Step 1: Transfer Code

```bash
# On server, clone or transfer your code
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

### Step 2: Configure

```bash
# Edit config.toml if needed
nano config.toml

# Or use environment variables (already set in compose file)
```

### Step 3: Generate Compose File

```bash
# Generate compose file for desired number of bots
./generate-bots.sh 50

# Or for different number
./generate-bots.sh 10
```

### Step 4: Build Images

```bash
# Build all bot images (this will take 10-15 minutes first time)
docker compose -f compose-50-bots.yaml build

# Or build in parallel (faster)
docker compose -f compose-50-bots.yaml build --parallel
```

### Step 5: Start Bots

```bash
# Start all bots in detached mode
docker compose -f compose-50-bots.yaml up -d

# Check status
docker compose -f compose-50-bots.yaml ps

# View logs
docker compose -f compose-50-bots.yaml logs -f
```

---

## Monitoring & Management

### Check Bot Status

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

### Stop/Start Bots

```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Stop specific bot
docker compose -f compose-50-bots.yaml stop bot-1

# Start specific bot
docker compose -f compose-50-bots.yaml start bot-1

# Restart all bots
docker compose -f compose-50-bots.yaml restart
```

### Resource Monitoring

```bash
# Check system resources
htop
# or
top

# Check disk space
df -h

# Check Docker disk usage
docker system df

# Clean up unused Docker resources
docker system prune -a
```

---

## Running in Background (Screen/Tmux)

### Using Screen

```bash
# Install screen
sudo apt-get install screen

# Start screen session
screen -S zoom-bots

# Run bots
docker compose -f compose-50-bots.yaml up -d

# Detach: Press Ctrl+A, then D
# Reattach: screen -r zoom-bots
```

### Using Tmux

```bash
# Install tmux
sudo apt-get install tmux

# Start tmux session
tmux new -s zoom-bots

# Run bots
docker compose -f compose-50-bots.yaml up -d

# Detach: Press Ctrl+B, then D
# Reattach: tmux attach -t zoom-bots
```

---

## Systemd Service (Auto-start on Boot)

### Create Service File

```bash
sudo nano /etc/systemd/system/zoom-bots.service
```

### Service Configuration

```ini
[Unit]
Description=Zoom Bots Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/meetingsdk-headless-linux-sample
ExecStart=/usr/bin/docker compose -f compose-50-bots.yaml up -d
ExecStop=/usr/bin/docker compose -f compose-50-bots.yaml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### Enable Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable zoom-bots.service

# Start service
sudo systemctl start zoom-bots.service

# Check status
sudo systemctl status zoom-bots.service

# View logs
sudo journalctl -u zoom-bots.service -f
```

---

## Troubleshooting

### Network Issues

```bash
# Test Zoom API connectivity
curl -I https://us05web.zoom.us

# Test DNS resolution
nslookup us05web.zoom.us

# Check firewall
sudo ufw status
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

# Clean Docker
docker system prune -a
```

### Bot-Specific Issues

```bash
# Check specific bot logs
docker logs zoom-bot-1 --tail 100

# Check all bot logs for errors
docker compose -f compose-50-bots.yaml logs | grep -i error

# Restart failed bots
docker compose -f compose-50-bots.yaml restart
```

---

## Security Best Practices

### 1. Firewall Configuration

```bash
# Install UFW
sudo apt-get install ufw

# Allow SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 2. SSH Security

```bash
# Disable password authentication (use keys only)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no

# Restart SSH
sudo systemctl restart sshd
```

### 3. Docker Security

```bash
# Don't run containers as root
# Already configured in Dockerfile

# Use Docker secrets for sensitive data
# (Not implemented in current setup, but recommended)
```

---

## Cost Estimation

### AWS EC2

- **t3.medium** (10 bots): ~$30/month
- **t3.large** (50 bots): ~$60/month
- **t3.xlarge** (100 bots): ~$120/month

### DigitalOcean

- **2GB RAM** (10 bots): $12/month
- **4GB RAM** (50 bots): $24/month
- **8GB RAM** (100 bots): $48/month

### Bandwidth

- Minimal bandwidth usage (~1GB/month for 50 bots)
- Usually included in server cost

---

## Quick Start Script

Create a deployment script:

```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 Starting Zoom Bots Deployment..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Generate compose file
NUM_BOTS=${1:-50}
echo "📝 Generating compose file for $NUM_BOTS bots..."
./generate-bots.sh $NUM_BOTS

# Build images
echo "🔨 Building Docker images..."
docker compose -f compose-50-bots.yaml build

# Start bots
echo "🚀 Starting bots..."
docker compose -f compose-50-bots.yaml up -d

# Check status
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
docker compose -f compose-50-bots.yaml ps

echo ""
echo "📝 View logs:"
echo "   docker compose -f compose-50-bots.yaml logs -f"
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh 50
```

---

## Next Steps

1. **Deploy to server** using one of the options above
2. **Monitor logs** to see if network issues are resolved
3. **Check Zoom meeting** to verify bots are joining
4. **Optimize** based on server performance

---

## Support

If you encounter issues:
1. Check logs: `docker compose -f compose-50-bots.yaml logs`
2. Check system resources: `htop`, `df -h`
3. Verify network: `curl -I https://us05web.zoom.us`
4. Review this guide's troubleshooting section


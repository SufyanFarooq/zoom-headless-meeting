# AWS EC2 Quick Start Guide

## Step-by-Step AWS Deployment

### 1. Launch EC2 Instance

1. **Login to AWS Console** → EC2 → Launch Instance

2. **Name:** `zoom-bots-server`

3. **AMI:** Ubuntu Server 22.04 LTS (Free tier eligible)

4. **Instance Type:**
   - **10 bots:** `t3.medium` (2 vCPU, 4GB RAM) - ~$30/month
   - **50 bots:** `t3.large` (2 vCPU, 8GB RAM) - ~$60/month
   - **100 bots:** `t3.xlarge` (4 vCPU, 16GB RAM) - ~$120/month

5. **Key Pair:** Create new or use existing (download `.pem` file)

6. **Network Settings:**
   - **Security Group:** Create new
   - **SSH (22):** Allow from your IP
   - **All Traffic:** Can be restricted later

7. **Storage:** 30GB gp3 (default is fine)

8. **Launch Instance**

### 2. Connect to Instance

```bash
# On your local machine
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### 3. One-Command Setup

```bash
# Run this on EC2 instance
curl -fsSL https://raw.githubusercontent.com/your-repo/deploy.sh | bash
```

Or manually:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login
exit
```

### 4. Transfer Code

**Option A: Git (if repo is public/accessible)**

```bash
# On EC2
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

**Option B: SCP from local machine**

```bash
# On your local machine
scp -i your-key.pem -r /path/to/meetingsdk-headless-linux-sample ubuntu@your-ec2-ip:~/
```

**Option C: Zip and transfer**

```bash
# On local machine
cd /path/to
zip -r meetingsdk.zip meetingsdk-headless-linux-sample
scp -i your-key.pem meetingsdk.zip ubuntu@your-ec2-ip:~/

# On EC2
unzip meetingsdk.zip
cd meetingsdk-headless-linux-sample
```

### 5. Deploy

```bash
# Generate compose file
./generate-bots.sh 50

# Build and start
./deploy.sh 50

# Or manually
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
```

### 6. Monitor

```bash
# Check status
docker compose -f compose-50-bots.yaml ps

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Count running bots
docker ps | grep zoom-bot | wc -l
```

## Cost Optimization

### Use Spot Instances (60-90% cheaper)

1. **EC2 → Spot Requests → Request Spot Instances**
2. Choose same instance type
3. **Max price:** Set to on-demand price or lower
4. **Interruption behavior:** Stop (bots will restart when instance resumes)

### Use Reserved Instances (30-60% cheaper)

1. **EC2 → Reserved Instances → Purchase Reserved Instances**
2. Choose 1-year or 3-year term
3. Significant savings for long-term use

## Security Best Practices

### 1. Restrict Security Group

```bash
# Only allow SSH from your IP
# In EC2 Console → Security Groups → Edit Inbound Rules
# SSH (22): Your IP only
```

### 2. Use IAM Roles (instead of access keys)

```bash
# EC2 → Instances → Select instance → Actions → Security → Modify IAM role
# Create role with minimal permissions
```

### 3. Enable CloudWatch Monitoring

```bash
# EC2 → Instances → Select instance → Monitoring → Enable detailed monitoring
```

## Auto-Start on Boot

### Using User Data Script

When launching EC2 instance, add this to **User Data**:

```bash
#!/bin/bash
cd /home/ubuntu
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
chmod +x deploy.sh
./deploy.sh 50
```

Or use systemd service (see main deployment guide).

## Troubleshooting

### Can't connect via SSH

```bash
# Check security group allows SSH from your IP
# Check instance is running
# Verify key file permissions: chmod 400 your-key.pem
```

### Out of memory

```bash
# Check instance type has enough RAM
# Use larger instance type
# Reduce number of bots
```

### High costs

```bash
# Use Spot Instances
# Use Reserved Instances
# Stop instance when not in use
# Use smaller instance type
```


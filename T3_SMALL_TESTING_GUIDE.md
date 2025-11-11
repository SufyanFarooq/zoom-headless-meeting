# Testing on t3.small - Resource-Constrained Setup

## t3.small Specifications

- **vCPU:** 2 cores
- **RAM:** 2 GB
- **Cost:** ~$15/month
- **Best for:** Testing with 5-10 bots

## Resource Limitations

### Per Bot Requirements
- **CPU:** ~0.05-0.1 core (idle) to 0.2-0.5 core (active)
- **RAM:** ~50-100 MB (running) to 200-400 MB (building)
- **Disk:** ~500 MB per bot (with build cache)

### Recommended Bot Counts

| Bot Count | Status | Notes |
|-----------|--------|-------|
| 1-5 bots | ✅ Safe | Plenty of resources |
| 5-10 bots | ✅ Recommended | Good for testing |
| 10-15 bots | ⚠️ Tight | Monitor resources closely |
| 15-20 bots | ⚠️ Maximum | May experience issues |
| 20+ bots | ❌ Not recommended | Will likely fail |

## Setup for t3.small

### Step 1: Launch t3.small Instance

1. **AWS Console** → EC2 → Launch Instance
2. **Instance Type:** `t3.small`
3. **AMI:** Ubuntu 22.04 LTS
4. **Storage:** 20GB (minimum)
5. **Security Group:** SSH (port 22) from your IP

### Step 2: Optimize for Low Memory

```bash
# Connect to instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Configure Docker for low memory
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "2"
  },
  "default-ulimits": {
    "memlock": {
      "hard": -1,
      "soft": -1
    }
  }
}
EOF

sudo systemctl restart docker

# Add swap space (helps with low memory)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap
free -h
```

### Step 3: Transfer Code

```bash
# On server
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

### Step 4: Generate Compose File for Fewer Bots

```bash
# For testing, use 5-10 bots
./generate-bots.sh 10

# Or even fewer for initial test
./generate-bots.sh 5
```

### Step 5: Modify Resource Limits (Important!)

Edit `compose-50-bots.yaml` to reduce resource limits:

```bash
# Use sed to reduce memory limits
sed -i 's/memory: 2G/memory: 512M/g' compose-50-bots.yaml
sed -i 's/memory: 512M/memory: 256M/g' compose-50-bots.yaml
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" compose-50-bots.yaml
sed -i "s/cpus: '0.2'/cpus: '0.1'/g" compose-50-bots.yaml
```

Or manually edit the compose file to set:
- **Memory limit:** 256M-512M per bot (instead of 2G)
- **CPU limit:** 0.3 cores per bot (instead of 1.0)
- **Memory reservation:** 128M (instead of 512M)
- **CPU reservation:** 0.05 (instead of 0.2)

### Step 6: Build and Start (One at a Time)

```bash
# Build one bot first to test
docker compose -f compose-50-bots.yaml build bot-1

# Start one bot
docker compose -f compose-50-bots.yaml up -d bot-1

# Check if it works
docker logs zoom-bot-1 -f

# If successful, build and start more (in batches)
docker compose -f compose-50-bots.yaml build bot-2 bot-3 bot-4 bot-5
docker compose -f compose-50-bots.yaml up -d bot-2 bot-3 bot-4 bot-5

# Monitor resources
htop
# or
docker stats
```

### Step 7: Monitor Resources

```bash
# Check memory usage
free -h

# Check CPU usage
top

# Check Docker resource usage
docker stats --no-stream

# Check running containers
docker ps | wc -l
```

## Optimized Compose File for t3.small

Create a custom compose file for low-resource testing:

```bash
# Create optimized compose file
cat > compose-t3-small.yaml << 'EOF'
services:
  bot-1:
    build: ./
    platform: linux/amd64
    container_name: zoom-bot-1
    volumes:
     - .:/tmp/meeting-sdk-linux-sample
     - build-cache:/tmp/meeting-sdk-linux-sample/build
    environment:
     - DISPLAY_NAME=Bot-1-Alice
     - JOIN_URL=${JOIN_URL}
     - CLIENT_ID=${CLIENT_ID}
     - CLIENT_SECRET=${CLIENT_SECRET}
     - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
     - QT_QPA_PLATFORM=offscreen
     - G_MESSAGES_DEBUG=
    entrypoint: ["/tini", "--", "./bin/entry-bot-optimized.sh"]
    command:
      - "--client-id"
      - "${CLIENT_ID}"
      - "--client-secret"
      - "${CLIENT_SECRET}"
      - "--join-url"
      - "${JOIN_URL}"
      - "--display-name"
      - "Bot-1-Alice"
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 512M
        reservations:
          cpus: '0.05'
          memory: 128M
    restart: no
volumes:
  build-cache:
EOF
```

## Testing Strategy

### Phase 1: Single Bot Test
```bash
# Test with 1 bot
./generate-bots.sh 1
docker compose -f compose-50-bots.yaml build bot-1
docker compose -f compose-50-bots.yaml up -d bot-1
docker logs zoom-bot-1 -f
```

### Phase 2: Small Batch Test
```bash
# Test with 5 bots
./generate-bots.sh 5
# Reduce resource limits (see Step 5)
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
docker stats
```

### Phase 3: Scale Up Gradually
```bash
# If 5 bots work, try 10
./generate-bots.sh 10
# Reduce resource limits
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
```

## Resource Monitoring Commands

```bash
# Real-time monitoring
watch -n 1 'free -h && echo "" && docker stats --no-stream | head -10'

# Check if system is swapping (bad sign)
vmstat 1 5

# Check Docker disk usage
docker system df

# Check container count
docker ps | wc -l
```

## Warning Signs

Stop adding bots if you see:
- **High swap usage** (`vmstat` shows si/so > 0)
- **Memory > 90%** (`free -h`)
- **Bots failing to start** (check logs)
- **Build failures** (out of memory)
- **System becoming unresponsive**

## Troubleshooting

### Out of Memory

```bash
# Check memory
free -h

# If memory is full:
# 1. Stop some bots
docker compose -f compose-50-bots.yaml stop bot-5 bot-6 bot-7 bot-8 bot-9 bot-10

# 2. Increase swap
sudo fallocate -l 4G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2
```

### Build Failures

```bash
# Build one at a time
docker compose -f compose-50-bots.yaml build bot-1

# Clean build cache if needed
docker builder prune -a
```

### Slow Performance

```bash
# Reduce bot count
docker compose -f compose-50-bots.yaml down
./generate-bots.sh 5  # Reduce to 5 bots
```

## Cost Comparison

| Instance | RAM | vCPU | Cost/Month | Max Bots |
|----------|-----|------|------------|----------|
| t3.small | 2GB | 2 | ~$15 | 10-15 |
| t3.medium | 4GB | 2 | ~$30 | 20-30 |
| t3.large | 8GB | 2 | ~$60 | 40-50 |
| t3.xlarge | 16GB | 4 | ~$120 | 80-100 |

## Recommendation

For **t3.small**:
- ✅ **Start with 5 bots** for initial testing
- ✅ **Scale to 10 bots** if resources allow
- ⚠️ **Monitor closely** - stop if memory > 85%
- ❌ **Don't try 50 bots** - will fail

For **production with 50 bots**, use **t3.large** or better.

## Quick Test Script

```bash
#!/bin/bash
# test-t3-small.sh

NUM_BOTS=${1:-5}

echo "🧪 Testing on t3.small with $NUM_BOTS bots"
echo ""

# Check resources
echo "📊 Current Resources:"
free -h
echo ""

# Generate compose file
./generate-bots.sh $NUM_BOTS

# Reduce resource limits
sed -i 's/memory: 2G/memory: 512M/g' compose-50-bots.yaml
sed -i 's/memory: 512M/memory: 256M/g' compose-50-bots.yaml
sed -i "s/cpus: '1.0'/cpus: '0.3'/g" compose-50-bots.yaml

# Build and start
echo "🔨 Building..."
docker compose -f compose-50-bots.yaml build

echo "🚀 Starting bots..."
docker compose -f compose-50-bots.yaml up -d

echo ""
echo "📊 Monitor with:"
echo "   docker stats"
echo "   free -h"
echo "   docker compose -f compose-50-bots.yaml logs -f"
```

Make executable:
```bash
chmod +x test-t3-small.sh
./test-t3-small.sh 5
```


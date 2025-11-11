#!/bin/bash
# GCP Quick Start Script - Automated Setup for 100 Bots

set -e

echo "🚀 GCP Quick Start - 100 Bots Deployment"
echo "========================================="
echo ""

# Check if running on GCP
check_gcp() {
    if [ -f /sys/class/dmi/id/product_name ] && grep -q "Google" /sys/class/dmi/id/product_name; then
        return 0
    elif curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name &>/dev/null; then
        return 0
    else
        return 1
    fi
}

if check_gcp; then
    echo "✅ Running on Google Cloud Platform"
else
    echo "⚠️  Not detected as GCP instance (continuing anyway)"
fi

echo ""

# Check system resources
echo "📊 System Resources:"
free -h
echo "CPU Cores: $(nproc)"
echo ""

# Check if resources are sufficient
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 8 ]; then
    echo "⚠️  WARNING: Less than 8GB RAM detected"
    echo "   Recommended: 8-16GB RAM for 100 bots"
    echo "   Current: ${TOTAL_RAM}GB"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo "📦 Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
    echo "⚠️  Please logout and login again, then run this script again"
    exit 0
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

# Add swap if memory is low
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ] && [ ! -f /swapfile ]; then
    echo "💾 Adding swap space..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile > /dev/null
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    echo "✅ Swap added (4GB)"
fi

# Configure Docker
echo "⚙️  Configuring Docker..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker > /dev/null 2>&1
echo "✅ Docker configured"

# Check if code is present
if [ ! -f "generate-bots.sh" ]; then
    echo "❌ Code not found. Please transfer code first."
    echo ""
    echo "Options:"
    echo "  1. Git clone: git clone <repo-url>"
    echo "  2. gcloud scp: gcloud compute scp --recurse ./code zoom-bots-server:~/ --zone=ZONE"
    exit 1
fi

# Generate compose file
NUM_BOTS=${1:-100}
echo ""
echo "📝 Generating compose file for $NUM_BOTS bots..."
./generate-bots.sh $NUM_BOTS

# Build images
echo ""
echo "🔨 Building Docker images..."
echo "   This will take 15-20 minutes for $NUM_BOTS bots..."
echo "   Building in parallel for faster completion..."
docker compose -f compose-50-bots.yaml build --parallel

# Start bots
echo ""
echo "🚀 Starting $NUM_BOTS bots..."
docker compose -f compose-50-bots.yaml up -d

# Wait for startup
echo "⏳ Waiting for bots to start..."
sleep 10

# Status
echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📊 Status:"
docker compose -f compose-50-bots.yaml ps | head -20

echo ""
echo "📊 Resource Usage:"
free -h
echo ""
echo "Top 10 containers by resource usage:"
docker stats --no-stream | head -11

echo ""
echo "📝 Useful Commands:"
echo "   View logs:        docker compose -f compose-50-bots.yaml logs -f"
echo "   Check status:     docker compose -f compose-50-bots.yaml ps"
echo "   Stop bots:        docker compose -f compose-50-bots.yaml down"
echo "   Monitor:          docker stats"
echo "   Count running:    docker ps | grep zoom-bot | wc -l"
echo ""
echo "💰 Cost Management:"
echo "   Stop instance:    gcloud compute instances stop zoom-bots-server --zone=ZONE"
echo "   Start instance:   gcloud compute instances start zoom-bots-server --zone=ZONE"
echo "   Check billing:    https://console.cloud.google.com/billing"
echo ""


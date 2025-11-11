#!/bin/bash
# Quick setup script for free trial cloud instances
# Works with AWS, DigitalOcean, GCP, Azure, etc.

set -e

echo "🚀 Free Trial Cloud Setup for 100 Bots"
echo "======================================"
echo ""

# Detect cloud provider (optional)
detect_provider() {
    if [ -f /sys/hypervisor/uuid ] && [ "$(head -c 3 /sys/hypervisor/uuid)" == "ec2" ]; then
        echo "AWS"
    elif [ -f /etc/digitalocean ]; then
        echo "DigitalOcean"
    elif [ -f /sys/class/dmi/id/product_name ] && grep -q "Google" /sys/class/dmi/id/product_name; then
        echo "GCP"
    else
        echo "Unknown"
    fi
}

PROVIDER=$(detect_provider)
echo "📊 Detected Provider: $PROVIDER"
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

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
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
    echo "💾 Adding swap space (helps with low memory)..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ Swap added (4GB)"
fi

# Configure Docker for better resource management
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

sudo systemctl restart docker
echo "✅ Docker configured"

# Check if code is present
if [ ! -f "generate-bots.sh" ]; then
    echo "❌ Code not found. Please transfer code first."
    echo ""
    echo "Options:"
    echo "  1. Git clone: git clone <repo-url>"
    echo "  2. SCP: scp -r code/ user@server:~/"
    exit 1
fi

# Generate compose file
NUM_BOTS=${1:-100}
echo ""
echo "📝 Generating compose file for $NUM_BOTS bots..."
./generate-bots.sh $NUM_BOTS

# Optimize for free tier (if needed)
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ]; then
    echo "⚙️  Optimizing resource limits for limited RAM..."
    sed -i 's/memory: 2G/memory: 512M/g' compose-50-bots.yaml
    sed -i 's/memory: 512M/memory: 256M/g' compose-50-bots.yaml
    sed -i "s/cpus: '1.0'/cpus: '0.2'/g" compose-50-bots.yaml
    echo "✅ Resource limits optimized"
fi

# Build and start
echo ""
echo "🔨 Building Docker images..."
echo "   This will take 15-20 minutes for 100 bots..."
docker compose -f compose-50-bots.yaml build

echo ""
echo "🚀 Starting $NUM_BOTS bots..."
docker compose -f compose-50-bots.yaml up -d

# Wait
sleep 10

# Status
echo ""
echo "✅ Setup Complete!"
echo ""
echo "📊 Status:"
docker compose -f compose-50-bots.yaml ps | head -20

echo ""
echo "📊 Resource Usage:"
free -h
echo ""
docker stats --no-stream | head -10

echo ""
echo "📝 Useful Commands:"
echo "   View logs:     docker compose -f compose-50-bots.yaml logs -f"
echo "   Check status:  docker compose -f compose-50-bots.yaml ps"
echo "   Stop bots:     docker compose -f compose-50-bots.yaml down"
echo "   Monitor:       docker stats"
echo ""


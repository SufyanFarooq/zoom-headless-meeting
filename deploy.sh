#!/bin/bash
# Quick deployment script for Zoom Bots

set -e

NUM_BOTS=${1:-50}
COMPOSE_FILE="compose-50-bots.yaml"

echo "🚀 Zoom Bots Deployment Script"
echo "================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. Please logout and login again, then run this script again."
    exit 0
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose not found. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Check if generate-bots.sh exists
if [ ! -f "generate-bots.sh" ]; then
    echo "❌ generate-bots.sh not found. Are you in the correct directory?"
    exit 1
fi

# Generate compose file
echo "📝 Generating compose file for $NUM_BOTS bots..."
./generate-bots.sh $NUM_BOTS

# Check if compose file was generated
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Failed to generate compose file"
    exit 1
fi

# Stop existing bots if running
echo "🛑 Stopping existing bots (if any)..."
docker compose -f $COMPOSE_FILE down 2>/dev/null || true

# Build images
echo "🔨 Building Docker images (this may take 10-15 minutes first time)..."
docker compose -f $COMPOSE_FILE build

# Start bots
echo "🚀 Starting $NUM_BOTS bots..."
docker compose -f $COMPOSE_FILE up -d

# Wait a moment
sleep 5

# Check status
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Current Status:"
docker compose -f $COMPOSE_FILE ps

echo ""
echo "📝 Useful Commands:"
echo "   View logs:        docker compose -f $COMPOSE_FILE logs -f"
echo "   Check status:     docker compose -f $COMPOSE_FILE ps"
echo "   Stop bots:        docker compose -f $COMPOSE_FILE down"
echo "   Restart bots:     docker compose -f $COMPOSE_FILE restart"
echo "   Count running:    docker ps | grep zoom-bot | wc -l"
echo "   Resource usage:   docker stats --no-stream | grep zoom-bot"
echo ""


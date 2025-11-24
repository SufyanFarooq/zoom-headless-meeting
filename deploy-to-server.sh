#!/bin/bash
# Quick deployment script for server

set -e

echo "🚀 Starting deployment..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "Please create .env file from .env.example"
    exit 1
fi

# Stop existing containers
echo "📦 Stopping existing containers..."
docker compose -f docker-compose.full.yml down

# Build and start services
echo "🔨 Building and starting services..."
docker compose -f docker-compose.full.yml up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if database needs initialization
echo "🗄️ Checking database..."
if ! docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "\dt" &>/dev/null; then
    echo "📊 Initializing database schema..."
    docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots < database/schema.sql
    echo "✅ Database initialized"
else
    echo "✅ Database already initialized"
fi

# Check service status
echo "📋 Service status:"
docker compose -f docker-compose.full.yml ps

# Check API health
echo "🏥 Checking API health..."
sleep 5
if curl -f http://localhost:3000/health &>/dev/null; then
    echo "✅ API is healthy"
else
    echo "⚠️ API health check failed"
fi

# Check scheduler
echo "⏰ Checking scheduler..."
if docker logs zoom-dashboard-api 2>&1 | grep -q "Starting scheduler"; then
    echo "✅ Scheduler is running"
else
    echo "⚠️ Scheduler not found in logs"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Register bot server: curl -X POST http://localhost:3000/api/bot-servers -H 'Content-Type: application/json' -d '{\"serverName\":\"server-1\",\"serverUrl\":\"http://localhost:3001\",\"capacity\":100}'"
echo "2. Check logs: docker compose -f docker-compose.full.yml logs -f"
echo "3. Access dashboard: http://localhost:8080"

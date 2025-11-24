#!/bin/bash

# Quick start script for full stack

echo "🚀 Starting Zoom Bot Dashboard..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating from .env.example..."
    cp .env.example .env
    echo "📝 Please edit .env file with your credentials before continuing"
    echo ""
    read -p "Press Enter after editing .env file..."
fi

# Start services
echo "🐳 Starting Docker containers..."
docker compose -f docker-compose.full.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are running
if docker ps | grep -q zoom-dashboard-api; then
    echo "✅ Dashboard API is running"
else
    echo "❌ Dashboard API failed to start"
    docker compose -f docker-compose.full.yml logs api
    exit 1
fi

if docker ps | grep -q zoom-dashboard-ui; then
    echo "✅ Dashboard UI is running"
else
    echo "❌ Dashboard UI failed to start"
    docker compose -f docker-compose.full.yml logs dashboard
    exit 1
fi

if docker ps | grep -q zoom-dashboard-db; then
    echo "✅ Database is running"
else
    echo "❌ Database failed to start"
    docker compose -f docker-compose.full.yml logs postgres
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All services started successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Dashboard: http://localhost:8080"
echo "🔌 API: http://localhost:3000"
echo "🤖 Bot Server API: http://localhost:3001"
echo ""
echo "💡 Next steps:"
echo "   1. Register bot server in database:"
echo "      docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots"
echo "      INSERT INTO bot_servers (server_name, server_url, capacity) VALUES ('server-1', 'http://bot-server-ip:3001', 100);"
echo ""
echo "   2. Access dashboard and create meetings!"
echo ""


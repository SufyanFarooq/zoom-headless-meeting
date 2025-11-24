#!/bin/bash
# Update bot server URL for Docker networking

echo "🔧 Updating bot server URL for Docker networking..."
echo ""

# Check if database is running
if ! docker ps | grep -q zoom-dashboard-db; then
    echo "❌ Database container not running"
    exit 1
fi

# Update bot server URL to use Docker service name
echo "Updating bot server URL to use Docker service name 'bot-server'..."
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "
UPDATE bot_servers 
SET server_url = 'http://bot-server:3001'
WHERE server_url LIKE '%localhost%' OR server_url LIKE '%127.0.0.1%';
"

if [ $? -eq 0 ]; then
    echo "✅ Bot server URL updated!"
    echo ""
    echo "Current bot servers:"
    docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "SELECT id, server_name, server_url, status FROM bot_servers;"
else
    echo "❌ Failed to update bot server URL"
    exit 1
fi

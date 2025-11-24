#!/bin/bash
# Fix bot server URL in database

echo "🔧 Fixing bot server URL in database..."
echo ""

# Check if we can connect to database
if ! docker ps | grep -q zoom-dashboard-db; then
    echo "❌ Database container not running"
    exit 1
fi

# Update bot server URL from localhost to 127.0.0.1
echo "Updating bot server URLs..."
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "
UPDATE bot_servers 
SET server_url = REPLACE(server_url, 'localhost', '127.0.0.1')
WHERE server_url LIKE '%localhost%';
"

if [ $? -eq 0 ]; then
    echo "✅ Bot server URLs updated!"
    echo ""
    echo "Current bot servers:"
    docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "SELECT id, server_name, server_url, status FROM bot_servers;"
else
    echo "❌ Failed to update bot server URLs"
    exit 1
fi

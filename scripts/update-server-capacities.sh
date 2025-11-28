#!/bin/bash

# Script to update server capacities
# Usage: ./update-server-capacities.sh [server1_capacity] [server2_capacity]

set -e

SERVER1_CAP="${1:-250}"
SERVER2_CAP="${2:-100}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Update Server Capacities"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Server 1 capacity: $SERVER1_CAP bots"
echo "Server 2 capacity: $SERVER2_CAP bots"
echo ""

# Check if database container exists
if ! docker ps | grep -q zoom-dashboard-db; then
    echo "❌ Database container not found"
    echo "   Make sure database is running:"
    echo "   docker ps | grep zoom-dashboard-db"
    exit 1
fi

echo "📝 Updating capacities..."

# Update Server 1
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots << EOF
UPDATE bot_servers SET capacity = $SERVER1_CAP WHERE server_name = 'server-1';
UPDATE bot_servers SET capacity = $SERVER2_CAP WHERE server_name = 'server-2';
EOF

if [ $? -eq 0 ]; then
    echo "✅ Capacities updated successfully!"
    echo ""
    
    echo "📋 Current Configuration:"
    docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
        "SELECT server_name, capacity, current_load, (capacity - current_load) as available, priority FROM bot_servers ORDER BY priority;"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Update Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💡 Now you can create meetings up to $SERVER1_CAP bots on Server 1"
    echo "   and up to $SERVER2_CAP bots on Server 2"
    echo ""
else
    echo "❌ Failed to update capacities"
    exit 1
fi

